
import UIKit
import CoreData
import Bond

/// methods in generic classes don't expose themselves to Objective-C, so we use this helper to forward our notifications
private class FRCDelegate: NSFetchedResultsControllerDelegate {
  init() {
    
  }
  
  var didChangeObjectHandler: ((anObject: AnyObject, indexPath: NSIndexPath?, type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) -> Void)?
  var didChangeSectionHandler: ((sectionInfo: NSFetchedResultsSectionInfo, sectionIndex: Int, type: NSFetchedResultsChangeType) -> Void)?
  
  private func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
    didChangeObjectHandler?(anObject: anObject, indexPath: indexPath, type: type, newIndexPath: newIndexPath)
  }
  private func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
    didChangeSectionHandler?(sectionInfo: sectionInfo, sectionIndex: sectionIndex, type: type)
  }
}

public class NSFetchedResultsDynamicArray<T: NSManagedObject>: DynamicArray<NSFetchedResultsSectionDynamicArray<T>> {
  private let frc: NSFetchedResultsController
  private let frcDelegate = FRCDelegate()
  
  public init<T>(fetchedResultsController: NSFetchedResultsController, type: T) {
    self.frc = fetchedResultsController
    frc.performFetch(nil)
    let sections = fetchedResultsController.sections as! [NSFetchedResultsSectionInfo]
    super.init(sections.map { NSFetchedResultsSectionDynamicArray(section: $0) })
    
    frcDelegate.didChangeSectionHandler = {[unowned self]sectionInfo, sectionIndex, type in
      switch type {
      case .Delete:
        self.removeAtIndex(sectionIndex)
      case .Insert:
        self.insert(NSFetchedResultsSectionDynamicArray(section: sectionInfo), atIndex: sectionIndex)
      default:
        fatalError("NSFetchedResultsController only notifies of section Insert or Delete")
      }
    }
    
    frcDelegate.didChangeObjectHandler = {[unowned self]anObject, indexPath, type, newIndexPath in
      switch type {
      case .Insert:
        let section = self[newIndexPath!.section]
        section.didChangeObject(anObject, atIndex: nil, forChangeType: type, newIndex: newIndexPath!.item)
      case .Delete:
        let section = self[indexPath!.section]
        section.didChangeObject(anObject, atIndex: indexPath!.item, forChangeType: type, newIndex: nil)
      case .Update:
        let section = self[indexPath!.section]
        section.didChangeObject(anObject, atIndex: indexPath!.item, forChangeType: type, newIndex: nil)
      case .Move:
        if indexPath!.section == newIndexPath!.section {
          let section = self[indexPath!.section]
          section.didChangeObject(anObject, atIndex: indexPath!.item, forChangeType: type, newIndex: newIndexPath!.item)
        } else {
          let oldSection = self[indexPath!.section]
          oldSection.didChangeObject(anObject, atIndex: indexPath!.item, forChangeType: .Delete, newIndex: nil)
          
          let newSection = self[newIndexPath!.section]
          newSection.didChangeObject(anObject, atIndex: nil, forChangeType: .Insert, newIndex: newIndexPath!.item)
        }
      }
    }
  
    frc.delegate = frcDelegate
  }

}

public class NSFetchedResultsSectionDynamicArray<T: NSManagedObject>: DynamicArray<T> {
  public let section: NSFetchedResultsSectionInfo
  
  init(section: NSFetchedResultsSectionInfo) {
    self.section = section
    let items = section.objects as! [T]
    super.init(items)
  }
  
  private func didChangeObject(anObject: AnyObject, atIndex index: Int?, forChangeType type: NSFetchedResultsChangeType, newIndex: Int?) {
    switch type {
    case .Delete:
      removeAtIndex(index!)
    case .Insert:
      insert(anObject as! T, atIndex: newIndex!)
    case .Move:
      if newIndex! < index! {
        removeAtIndex(index!)
        insert(anObject as! T, atIndex: newIndex!)
      } else {
        removeAtIndex(index!)
        insert(anObject as! T, atIndex: newIndex! - 1)
      }
    case .Update:
      self[newIndex!] = anObject as! T
    }
  }

}