//
//  PhotosCollectionViewController.swift
//  PhotoSearch
//
//  Created by Nadim Alam on 16/01/2019.
//  Copyright © 2019 Nadim Alam. All rights reserved.
//

import UIKit

class PhotosCollectionViewController: UICollectionViewController {

    // MARK: - Private Properties
    
    private let reuseIdentifier = "PhotoCell"
    
    private let sectionInsets = UIEdgeInsets(top: 50.0,
                                             left: 20.0,
                                             bottom: 50.0,
                                             right: 20.0)
    
    private var searches: [PhotoSearchResults] = []
    private let apiService = APIService()
    private let itemsPerRow: CGFloat = 2
    
    // Array to track all currently selected photos while in sharing mode.
    private var selectedPhotos: [Photo] = []
    // Feedback for how many photos are currently selected.
    private let shareLabel = UILabel()
    
    // Variable to hold the currently selected photo item.
    private var largePhotoIndexPath: IndexPath? {
        didSet {
            // Update the collectionView using didSet...
            var indexPaths: [IndexPath] = []
            if let largePhotoIndexPath = largePhotoIndexPath {
                indexPaths.append(largePhotoIndexPath)
            }
            
            if let oldValue = oldValue {
                indexPaths.append(oldValue)
            }
            // Animate the changes
            collectionView.performBatchUpdates({
                self.collectionView.reloadItems(at: indexPaths)
            }) { _ in
                // Scroll the selected cell to the middle of the screen.
                if let largePhotoIndexPath = self.largePhotoIndexPath {
                    self.collectionView.scrollToItem(at: largePhotoIndexPath,
                                                     at: .centeredVertically,
                                                     animated: true)
                }
            }
        }
    }
    
    private var sharing: Bool = false {
        
        didSet {
            // Allow multiple cell selection.
            collectionView.allowsMultipleSelection = sharing
            
            // Remove cell selection, scroll to top, reset all selected photos.
            collectionView.selectItem(at: nil, animated: true, scrollPosition: [])
            selectedPhotos.removeAll()
            
            guard let shareButton = self.navigationItem.rightBarButtonItems?.first else {
                return
            }
            
            // Set the share bar button to the default state and return if sharing is not enabled.
            guard sharing else {
                navigationItem.setRightBarButton(shareButton, animated: true)
                return
            }
            
            // Set the largePhotoIndexPath to nil.
            if largePhotoIndexPath != nil {
                largePhotoIndexPath = nil
            }
            
            // Update the label
            updateSharedPhotoCountLabel()
            
            // Update the navigation bar buttons accordingly.
            let sharingItem = UIBarButtonItem(customView: shareLabel)
            let items: [UIBarButtonItem] = [
                shareButton,
                sharingItem
            ]
            
            navigationItem.setRightBarButtonItems(items, animated: true)
        }
    }
}

// MARK: - Private

private extension PhotosCollectionViewController {
    
    func photo(for indexPath: IndexPath) -> Photo {
        return searches[indexPath.section].searchResults[indexPath.row]
    }
    
    func removePhoto(at indexPath: IndexPath) {
        searches[indexPath.section].searchResults.remove(at: indexPath.row)
    }
    
    func insertPhoto(_ newPhoto: Photo, at indexPath: IndexPath) {
        searches[indexPath.section].searchResults.insert(newPhoto, at: indexPath.row)
    }
    
    func performLargeImageFetch(for indexPath: IndexPath, photo: Photo) {
        
        // Make sure dequeued a cell of the right type.
        guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCollectionViewCell else {
            return
        }
        
        // Start the activity indicator for network activity.
        cell.activityIndicator.startAnimating()
        
        // Start the image download.
        photo.loadLargeImage { [weak self] result in
            // Ensure the view controller is still a valid object as we are in a closure.
            guard let self = self else {
                return
            }
            
            switch result {
                // Set the imageView on the cell to the photos largeImage if indexPath matches.
                case .results(let photo):
                    if indexPath == self.largePhotoIndexPath {
                        cell.imageView.image = photo.largeImage
                    }
                case .error(_):
                    return
            }
        }
    }
    
    func updateSharedPhotoCountLabel() {
        
        if sharing {
            shareLabel.text = "\(selectedPhotos.count) photos selected"
        } else {
            shareLabel.text = ""
        }
        
        shareLabel.textColor = .blue
        
        UIView.animate(withDuration: 0.3) {
            self.shareLabel.sizeToFit()
        }
    }
}

// MARK:- Outlets

extension PhotosCollectionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Enable Drag Interaction on the CollectionView.
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
    }
    
    @IBAction func share(_ sender: Any) {
        
        guard !searches.isEmpty else {
            return
        }
        
        guard !selectedPhotos.isEmpty else {
            sharing.toggle()
            return
        }
        
        guard sharing else {
            return
        }
        
        // The photo sharing logic.
        let images: [UIImage] = selectedPhotos.compactMap { photo in
            if let thumbnail = photo.thumbnail {
                return thumbnail
            }
            
            return nil
        }
        
        guard !images.isEmpty else {
            return
        }
        
        // Add the Activity Sheet.
        let shareController = UIActivityViewController(
            activityItems: images,
            applicationActivities: nil)
        shareController.completionWithItemsHandler = { _, _, _, _ in
            self.cleanupSharing()
        }
        
        shareController.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
        shareController.popoverPresentationController?.permittedArrowDirections = .any
        present(shareController, animated: true, completion: nil)
    }
    
    @IBAction func clearButtonPressed() {
        cleanupSharing()
        self.searches.removeAll(keepingCapacity: true)
        self.collectionView.restore()
        self.collectionView.reloadData()
    }
    
    func cleanupSharing() {
        self.sharing = false
        self.selectedPhotos.removeAll()
        self.updateSharedPhotoCountLabel()
    }
}

// MARK: - Text Field Delegate

extension PhotosCollectionViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        // Add an activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        textField.addSubview(activityIndicator)
        activityIndicator.frame = textField.bounds
        activityIndicator.startAnimating()
        
        // Search the API service asynchronously for photos that match the given search term.
        apiService.searchAPIService(for: textField.text!) { searchResults in
            activityIndicator.removeFromSuperview()
            
            switch searchResults {
            case .error(let error) :
                // Log any errors to console.
                // TODO: Display error to user.
                print("Error Searching: \(error)")
            case .results(let results):
                // Log the results and insert them in the searches array.
                print("Found \(results.searchResults.count) matching \(results.searchTerm)")
                self.searches.insert(results, at: 0)
                // Refresh the UI.
                self.collectionView?.reloadData()
            }
        }
        
        textField.text = nil
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UICollectionViewDataSource

extension PhotosCollectionViewController {
    
    // Return the number of searches.
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        searches.count == 0 ?
            self.collectionView.setEmptyMessage("No photos found. \nPlease start a search.") :
            self.collectionView.restore()
        
        return searches.count
    }
    
    // Return the number of search results for each section.
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searches[section].searchResults.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? PhotoCollectionViewCell else {
                preconditionFailure("Invalid cell type")
        }
        
        let newPhoto = photo(for: indexPath)
        
        // Stop the activity indicator.
        cell.activityIndicator.stopAnimating()
        
        // if the largePhotoIndexPath doesnt match the indexPath of the cell
        // set the image to thumbnail and return.
        guard indexPath == largePhotoIndexPath else {
            cell.imageView.image = newPhoto.thumbnail
            return cell
        }
        
        // If the largePhotoIndexPath isnt nil, set the image to the large image and return.
        guard newPhoto.largeImage == nil else {
            cell.imageView.image = newPhoto.largeImage
            return cell
        }
        
        // Set the thumbnail first.
        cell.imageView.image = newPhoto.thumbnail
        
        // Fetch the large image version and return the cell.
        performLargeImageFetch(for: indexPath, photo: newPhoto)
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        switch kind {
            case UICollectionView.elementKindSectionHeader:
                // Dequeue the the header using the identifier from the storyboard.
                guard
                    let headerView = collectionView.dequeueReusableSupplementaryView(
                        ofKind: kind,
                        withReuseIdentifier: "\(PhotoHeaderView.self)",
                        for: indexPath) as? PhotoHeaderView
                    else {
                        fatalError("Invalid view type")
                }
                // Set and return the header view.
                let searchTerm = searches[indexPath.section].searchTerm
                headerView.label.text = searchTerm
                return headerView
            default:
                // Ensure this is the right response type.
                assert(false, "Invalid element type")
        }
    }
}

// MARK: - Collection View Flow Layout Delegate

extension PhotosCollectionViewController: UICollectionViewDelegateFlowLayout {
    
    // Size of the given cell.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if indexPath == largePhotoIndexPath {
            let newPhoto = photo(for: indexPath)
            var size = collectionView.bounds.size
            size.height -= (sectionInsets.top + sectionInsets.bottom)
            size.width -= (sectionInsets.left + sectionInsets.right)
            return newPhoto.sizeToFillWidth(of: size)
        }
        
        // Calculates the padding size.
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    // Returns the spacing between the cells, headers and footers.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    // Spacing between each line in the layout.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return sectionInsets.left
    }
}

// MARK: - UICollectionViewDelegate

extension PhotosCollectionViewController {
    
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        
        // Only allow large photo selection when we are not in the sharing selection mode.
        guard !sharing else {
            return true
        }
        
        if largePhotoIndexPath == indexPath {
            largePhotoIndexPath = nil
        } else {
            largePhotoIndexPath = indexPath
        }
        
        return false
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Return if not in sharing mode.
        guard sharing else {
            return
        }
        
        let newPhoto = photo(for: indexPath)
        selectedPhotos.append(newPhoto)
        updateSharedPhotoCountLabel()
    }
    
    override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        // Return if not in sharing mode.
        guard sharing else {
            return
        }
        
        // On deselection remove the item from the photos array and update the share label.
        let newPhoto = photo(for: indexPath)
        if let index = selectedPhotos.firstIndex(of: newPhoto) {
            selectedPhotos.remove(at: index)
            updateSharedPhotoCountLabel()
        }
    }
}

// MARK: - UICollectionViewDragDelegate

extension PhotosCollectionViewController: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        
        let newPhoto = photo(for: indexPath)
        guard let thumbnail = newPhoto.thumbnail else {
            return []
        }
        let item = NSItemProvider(object: thumbnail)
        let dragItem = UIDragItem(itemProvider: item)
        return [dragItem]
    }
}

// MARK: - UICollectionViewDropDelegate

extension PhotosCollectionViewController: UICollectionViewDropDelegate {    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        
        // Get the destinationIndexPath from the drop coordinator.
        guard let destinationIndexPath = coordinator.destinationIndexPath else {
            return
        }
        
        // Loop through the UICollectionViewDropItem and make sure each item has a sourceIndexPath.
        coordinator.items.forEach { dropItem in
            guard let sourceIndexPath = dropItem.sourceIndexPath else {
                return
            }
            
            // Update the collection view.
            collectionView.performBatchUpdates({
                let image = photo(for: sourceIndexPath)
                removePhoto(at: sourceIndexPath)
                insertPhoto(image, at: destinationIndexPath)
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [destinationIndexPath])
            }, completion: { _ in
                // Perform the drop action.
                coordinator.drop(dropItem.dragItem,
                                 toItemAt: destinationIndexPath)
            })
        }
    }
    
    // Makes sure that the collection view responds to the drop session, making sure that the item is moved correctly.
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession,  withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
}
