import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

struct LocalizationListItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    let revealed: Bool
    let reorderable: Bool
}

class LocalizationListItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let id: String
    let title: String
    let subtitle: String
    let checked: Bool
    let activity: Bool
    let editing: LocalizationListItemEditing
    let sectionId: ItemListSectionId
    let alwaysPlain: Bool
    let action: () -> Void
    let setItemWithRevealedOptions: (String?, String?) -> Void
    let removeItem: (String) -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, id: String, title: String, subtitle: String, checked: Bool, activity: Bool, editing: LocalizationListItemEditing, sectionId: ItemListSectionId, alwaysPlain: Bool, action: @escaping () -> Void, setItemWithRevealedOptions: @escaping (String?, String?) -> Void, removeItem: @escaping (String) -> Void) {
        self.theme = theme
        self.strings = strings
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.checked = checked
        self.activity = activity
        self.editing = editing
        self.sectionId = sectionId
        self.alwaysPlain = alwaysPlain
        self.action = action
        self.setItemWithRevealedOptions = setItemWithRevealedOptions
        self.removeItem = removeItem
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LocalizationListItemNode()
            var neighbors = itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem)
            if previousItem is ChatListSearchItem || self.alwaysPlain {
                neighbors.top = .sameSection(alwaysPlain: false)
            }
            let (layout, apply) = node.asyncLayout()(self, params, neighbors)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(false) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? LocalizationListItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    var neighbors = itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem)
                    if previousItem is ChatListSearchItem || self.alwaysPlain {
                        neighbors.top = .sameSection(alwaysPlain: false)
                    }
                    let (layout, apply) = makeLayout(self, params, neighbors)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

private let titleFont = Font.regular(17.0)
private let subtitleFont = Font.regular(13.0)

class LocalizationListItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let iconNode: ASImageNode
    private let activityNode: ActivityIndicator
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    
    private var item: LocalizationListItem?
    private var layoutParams: (ListViewItemLayoutParams, ItemListNeighbors)?
    
    private var editableControlNode: ItemListEditableControlNode?
    private var reorderControlNode: ItemListEditableReorderControlNode?
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil {
            return false
        }
        if let _ = self.layoutParams?.0 {
            return super.canBeSelected
        } else {
            return false
        }
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.activityNode = ActivityIndicator(type: ActivityIndicatorType.custom(.black, 22.0, 0.0, false))
        self.activityNode.isHidden = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreenScale
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.contentMode = .left
        self.subtitleNode.contentsScale = UIScreenScale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.activityNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    func asyncLayout() -> (_ item: LocalizationListItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var leftInset: CGFloat = params.leftInset
            
            let insets = itemListNeighborsGroupedInsets(neighbors)
            let contentSize = CGSize(width: params.width, height: 58.0)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            var editableControlSizeAndApply: (CGSize, () -> ItemListEditableControlNode)?
            
            var editingOffset: CGFloat = 0.0
            
            if item.editing.editing {
                let sizeAndApply = editableControlLayout(layout.contentSize.height, item.theme, false)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0.width
            }
            
            leftInset += 16.0
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 50.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.subtitle, font: subtitleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 50.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let separatorHeight = UIScreenPixel
            
            var updateCheckImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            if currentItem?.theme !== item.theme {
                updateCheckImage = PresentationResourcesItemList.checkIconImage(item.theme)
            }
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = (params, neighbors)
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let updateCheckImage = updateCheckImage {
                        strongSelf.iconNode.image = updateCheckImage
                        strongSelf.activityNode.type = ActivityIndicatorType.custom(item.theme.list.itemAccentColor, 22.0, 0.0, false)
                    }
                    
                    strongSelf.activityNode.isHidden = !item.activity
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    let _ = subtitleApply()
                    
                    if let image = strongSelf.iconNode.image {
                        transition.updateFrame(node: strongSelf.iconNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + params.width - params.rightInset - image.size.width - floor((44.0 - image.size.width) / 2.0), y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size))
                    }
                    let activitySize = CGSize(width: 22.0, height: 22.0)
                    transition.updateFrame(node: strongSelf.activityNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + params.width - params.rightInset - activitySize.width - floor((44.0 - activitySize.width) / 2.0), y: floor((contentSize.height - activitySize.height) / 2.0)), size: activitySize))
                    strongSelf.iconNode.isHidden = !item.checked || item.activity
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            strongSelf.topStripeNode.isHidden = false
                    }
                    let bottomStripeInset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset
                        default:
                            bottomStripeInset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + leftInset, y: 8.0), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.subtitleNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + leftInset, y: 31.0), size: subtitleLayout.size))
                    
                    if let editableControlSizeAndApply = editableControlSizeAndApply {
                        if strongSelf.editableControlNode == nil {
                            let editableControlNode = editableControlSizeAndApply.1()
                            editableControlNode.tapped = {
                                if let strongSelf = self {
                                    strongSelf.setRevealOptionsOpened(true, animated: true)
                                    strongSelf.revealOptionsInteractivelyOpened()
                                }
                            }
                            strongSelf.editableControlNode = editableControlNode
                            strongSelf.addSubnode(editableControlNode)
                            let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: 0.0), size: editableControlSizeAndApply.0)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        }
                        strongSelf.editableControlNode?.isHidden = !item.editing.editable
                    } else if let editableControlNode = strongSelf.editableControlNode {
                        var editableControlFrame = editableControlNode.frame
                        editableControlFrame.origin.x = -editableControlFrame.size.width
                        strongSelf.editableControlNode = nil
                        transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                        transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                            editableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    if item.editing.editable {
                        strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                    } else {
                        strongSelf.setRevealOptions((left: [], right: []))
                    }
                    strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        guard let params = self.layoutParams?.0 else {
            return
        }
        
        var leftInset: CGFloat = params.leftInset
        leftInset += 16.0
        
        var editingOffset: CGFloat = 0.0
        if let editableControlNode = self.editableControlNode {
            editingOffset += editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = params.leftInset + offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        }
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: editingOffset + leftInset + offset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: editingOffset + leftInset + offset, y: self.subtitleNode.frame.minY), size: self.subtitleNode.bounds.size))
        
        if let image = self.iconNode.image {
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: editingOffset + offset + params.width - params.rightInset - image.size.width - floor((44.0 - image.size.width) / 2.0), y: self.iconNode.frame.minY), size: self.iconNode.bounds.size))
        }
        let activitySize = CGSize(width: 22.0, height: 22.0)
        transition.updateFrame(node: self.activityNode, frame: CGRect(origin: CGPoint(x: editingOffset + offset + params.width - params.rightInset - activitySize.width - floor((44.0 - activitySize.width) / 2.0), y: floor((contentSize.height - activitySize.height) / 2.0)), size: activitySize))
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            item.setItemWithRevealedOptions(item.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            item.setItemWithRevealedOptions(nil, item.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let item = self.item {
            item.removeItem(item.id)
        }
    }
}
