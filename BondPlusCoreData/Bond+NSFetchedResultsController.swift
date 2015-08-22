
import CoreData
import Bond

/// methods in generic classes don't expose themselves to Objective-C, so we use this helper to forward our notifications
private class FRCDelegate: NSObject, NSFetchedResultsControllerDelegate {
  
  var didChangeObjectHandler: ((anObject: AnyObject, indexPath: NSIndexPath?, type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) -> Void)?
  var didChangeSectionHandler: ((sectionInfo: NSFetchedResultsSectionInfo, sectionIndex: Int, type: NSFetchedResultsChangeType) -> Void)?
  var willChangeContentHandler: (() -> Void)?
  var didChangeContentHandler: (() -> Void)?
  @objc private func controllerWillChangeContent(controller: NSFetchedResultsController) {
    willChangeContentHandler?()
  }
  
  @objc private func controllerDidChangeContent(controller: NSFetchedResultsController) {
    didChangeContentHandler?()
  }
  
  @objc private func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
    if type == .Insert { print("FRC did insert at index: \(newIndexPath!.item)") }
    didChangeObjectHandler?(anObject: anObject, indexPath: indexPath, type: type, newIndexPath: newIndexPath)
  }
  
  @objc private func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
    didChangeSectionHandler?(sectionInfo: sectionInfo, sectionIndex: sectionIndex, type: type)
  }
}

public class NSFetchedResultsDynamicArray<T: NSManagedObject>: DynamicArray<DynamicArray<T>> {
  private let frc: NSFetchedResultsController
  private let frcDelegate = FRCDelegate()
  private var pendingInserts = [(NSFetchedResultsSectionDynamicArray<T>, Int)]()
  private var pendingDeletes = [Int]()
  
  public init(fetchedResultsController: NSFetchedResultsController) {
    self.frc = fetchedResultsController
    do {
      try frc.performFetch()
    } catch _ {
    }
    let sections = fetchedResultsController.sections!
    super.init(sections.map { NSFetchedResultsSectionDynamicArray(section: $0) })
    
    frcDelegate.didChangeSectionHandler = {[unowned self]sectionInfo, sectionIndex, type in
      switch type {
      case .Delete:
        self.pendingDeletes.append(sectionIndex)
      case .Insert:
        let newSection = NSFetchedResultsSectionDynamicArray<T>(section: sectionInfo)
        newSection.willChangeContent()
        self.pendingInserts.append(newSection, sectionIndex)
      default:
        fatalError("NSFetchedResultsController only notifies of section Insert or Delete")
      }
    }
    
    frcDelegate.didChangeObjectHandler = {[unowned self]anObject, indexPath, type, newIndexPath in
      print("didChangeObjectHandler called: \(type.rawValue)")
      switch type {
      case .Insert:
        let section = self[newIndexPath!.section]
        (section as! NSFetchedResultsSectionDynamicArray).didChangeObject(anObject, atIndex: nil, forChangeType: type, newIndex: newIndexPath!.item)
      case .Delete:
        let section = self[indexPath!.section]
        (section as! NSFetchedResultsSectionDynamicArray).didChangeObject(anObject, atIndex: indexPath!.item, forChangeType: type, newIndex: nil)
      case .Update:
        let section = self[indexPath!.section]
        (section as! NSFetchedResultsSectionDynamicArray).didChangeObject(anObject, atIndex: indexPath!.item, forChangeType: type, newIndex: nil)
      case .Move:
        if indexPath!.section == newIndexPath!.section {
          let section = self[indexPath!.section]
          (section as! NSFetchedResultsSectionDynamicArray).didChangeObject(anObject, atIndex: indexPath!.item, forChangeType: type, newIndex: newIndexPath!.item)
        } else {
          let oldSection = self[indexPath!.section]
          (oldSection as! NSFetchedResultsSectionDynamicArray).didChangeObject(anObject, atIndex: indexPath!.item, forChangeType: .Delete, newIndex: nil)
          
          let newSection = self[newIndexPath!.section]
          (newSection as! NSFetchedResultsSectionDynamicArray).didChangeObject(anObject, atIndex: nil, forChangeType: .Insert, newIndex: newIndexPath!.item)
        }
      }
    }
    
    frcDelegate.willChangeContentHandler = {[unowned self] in
      assert(self.pendingInserts.isEmpty && self.pendingDeletes.isEmpty)
      for section in self {
        (section as! NSFetchedResultsSectionDynamicArray).willChangeContent()
      }
    }
    
    frcDelegate.didChangeContentHandler = {[unowned self] in
      for (section, index) in self.pendingInserts {
        self.insert(section, atIndex: index)
      }
      for index in self.pendingDeletes.sort(>) {
        let deadSection = self.removeAtIndex(index)
        (deadSection as! NSFetchedResultsSectionDynamicArray).didChangeContent()
      }
      for section in self {
        (section as! NSFetchedResultsSectionDynamicArray).didChangeContent()
      }
      self.pendingInserts.removeAll(keepCapacity: false)
      self.pendingDeletes.removeAll(keepCapacity: false)
    }
    
    frc.delegate = frcDelegate
  }
  
}

public class NSFetchedResultsSectionDynamicArray<T: NSManagedObject>: DynamicArray<T> {
  public let section: NSFetchedResultsSectionInfo
  private var pendingInserts = [(T, Int)]()
  private var pendingDeletes = [Int]()
  private var pendingUpdates = [Int]()
  
  init(section: NSFetchedResultsSectionInfo) {
    self.section = section
    let items = section.objects as! [T]
    super.init(items)
  }
  
  private func willChangeContent() {
    assert(pendingInserts.isEmpty && pendingDeletes.isEmpty && pendingUpdates.isEmpty, "changing content while already changing content")
  }
  
  private func didChangeContent() {
    for (obj, index) in pendingInserts.sort({ $0.1 < $1.1 }) {
      print("Dispatching insert at index: \(index)")
      insert(obj, atIndex: index)
    }
    for index in pendingDeletes.sort(>) {
      removeAtIndex(index)
    }
    for index in pendingUpdates {
      self[index] = self[index]
    }
    pendingInserts.removeAll(keepCapacity: false)
    pendingUpdates.removeAll(keepCapacity: false)
    pendingDeletes.removeAll(keepCapacity: false)
    precondition(pendingInserts.isEmpty)
    print("Pending inserts cleared!")
  }
  
  private func didChangeObject(anObject: AnyObject, atIndex index: Int?, forChangeType type: NSFetchedResultsChangeType, newIndex: Int?) {
    switch type {
    case .Delete:
      pendingDeletes.append(index!)
    case .Insert:
      print("Enqueued pending insert: \(newIndex!)")
      pendingInserts.append(anObject as! T, newIndex!)
    case .Move:
      if newIndex! < index! {
        pendingDeletes.append(index!)
        pendingInserts.append(anObject as! T, newIndex!)
      } else {
        pendingDeletes.append(index!)
        pendingInserts.append((anObject as! T, newIndex! - 1))
      }
    case .Update:
      pendingUpdates.append(index!)
    }
  }
  
}