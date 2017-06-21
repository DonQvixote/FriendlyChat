//
//  FriendlyChatViewController.swift
//  FriendlyChat
//
//  Created by 夏语诚 on 2017/6/20.
//  Copyright © 2017年 Banana Inc. All rights reserved.
//

import UIKit
import Photos
import Firebase
import GoogleSignIn
import GoogleMobileAds

/**
 * AdMob ad unit IDs are not currently stored inside the google-services.plist file. Developers
 * using AdMob can store them as custom values in another plist, or simply use constants. Note that
 * these ad units are configured to return only test ads, and should not be used outside this sample.
 */
let kBannerAdUnitID = "ca-app-pub-6251245455764786/3236845554"
class FriendlyChatViewController: UIViewController, FIRInviteDelegate {
    
    var ref: FIRDatabaseReference!
    var messages: [FIRDataSnapshot]! = []
    var msglength: NSNumber = 10
    fileprivate var _refHandle: FIRDatabaseHandle?
    
    var storageRef: FIRStorageReference!
    var remoteConfig: FIRRemoteConfig!
    
    @IBOutlet weak var clientTable: UITableView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var banner: GADBannerView!
    
    @IBAction func didPressCrash(_ sender: Any) {
        FIRCrashMessage("Cause Crash button clicked")
        fatalError()
    }
    
    @IBAction func didPressFreshConfig(_ sender: Any) {
        fetchConfig()
    }
    
    @IBAction func inviteTapped(_ sender: Any) {
        if let invite = FIRInvites.inviteDialog() {
            invite.setInviteDelegate(self)
            
            // NOTE: You must have the App Store ID set in your developer console project
            // in order for invitations to successfully be sent.
            
            // A message hint for the dialog. Note this manifests differently depending on the
            // received invitation type. For example, in an email invite this appears as the subject.
            invite.setMessage("Try this out!\n -\(FIRAuth.auth()?.currentUser?.displayName ?? "")")
            // Title for the dialog, this is what the user sees before sending the invites.
            invite.setTitle("FriendlyChat")
            invite.setDeepLink("app_url")
            invite.setCallToActionText("Install!")
            invite.setCustomImage("https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png")
            invite.open()
        }
    }
    
    @IBAction func signOut(_ sender: UIButton) {
        let firebaseAuth = FIRAuth.auth()
        do {
            try firebaseAuth?.signOut()
            dismiss(animated: true, completion: nil)
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }
    }
    
    @IBAction func didTapAddPhoto(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func didSendMessage(_ sender: UIButton) {
        _ = textFieldShouldReturn(textField)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.clientTable.register(UITableViewCell.self, forCellReuseIdentifier: "tableViewCell")
        clientTable.dataSource = self
        clientTable.delegate = self
        
        configureDatabase()
        configureStorage()
        configureRemoteConfig()
        fetchConfig()
        loadAd()
        logViewLoaded()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        if let refHandle = _refHandle {
            self.ref.child("messages").removeObserver(withHandle: refHandle)
        }
    }
    
    func configureDatabase() {
        ref = FIRDatabase.database().reference()
        // Listen for new messages in the Firebase database
        _refHandle = self.ref.child("messages").observe(.childAdded, with: { [weak self] (snapshot) in
            guard let strongSelf = self else { return }
            strongSelf.messages.append(snapshot)
            strongSelf.clientTable.insertRows(at: [IndexPath(row: strongSelf.messages.count-1, section: 0)], with: .automatic)
        })
    }
    
    func configureStorage() {
        storageRef = FIRStorage.storage().reference()
    }
    
    func configureRemoteConfig() {
        remoteConfig = FIRRemoteConfig.remoteConfig()
        // Create Remote Config Setting to enable developer mode.
        // Fetching configs from the server is normally limited to 5 requests per hour.
        // Enabling developer mode allows many more requests to be made per hour, so developers
        // can test different config values during development.
        let remoteConfigSettings = FIRRemoteConfigSettings(developerModeEnabled: true)
        remoteConfig.configSettings = remoteConfigSettings!
    }
    
    func fetchConfig() {
        var expirationDuration: Double = 3600
        
        // If in developer mode cacheExpiration is set to 0 so each fetch will retrieve values from
        // the server.
        if self.remoteConfig.configSettings.isDeveloperModeEnabled {
            expirationDuration = 0
        }
        
        // cacheExpirationSeconds is set to cacheExpiration here, indicating that any previously
        // fetched and cached config would be considered expired because it would have been fetched
        // more than cacheExpiration seconds ago. Thus the next fetch would go to the server unless
        // throttling is in progress. The default expiration duration is 43200 (12 hours).
        remoteConfig.fetch(withExpirationDuration: expirationDuration) { [weak self] (status, error) in
            if status == .success {
                print("Config fetched!")
                guard let strongSelf = self else { return }
                strongSelf.remoteConfig.activateFetched()
                let friendlyMsgLength = strongSelf.remoteConfig["friendly_msg_length"]
                if friendlyMsgLength.source != .static {
                    strongSelf.msglength = friendlyMsgLength.numberValue!
                    print("Friendly msg length config: \(strongSelf.msglength)")
                }
            } else {
                print("Config not fetched")
                if let error = error {
                    print("Error \(error)")
                }
            }
        }
    }
    
    func sendMessage(withData data: [String: String]) {
        var mdata = data
        mdata[Constants.MessageFields.name] = FIRAuth.auth()?.currentUser?.displayName
        if let photoURL = FIRAuth.auth()?.currentUser?.photoURL {
            mdata[Constants.MessageFields.photoURL] = photoURL.absoluteString
        }
        
        // Push data to Firebase Database
        self.ref.child("messages").childByAutoId().setValue(mdata)
    }

    func inviteFinished(withInvitations invitationIds: [Any], error: Error?) {
        if let error = error {
            print("Failed: \(error.localizedDescription)")
        } else {
            print("Invitations sent")
        }
    }
    
    func logViewLoaded() {
        FIRCrashMessage("View loaded")
    }
    
    func loadAd() {
        self.banner.adUnitID = kBannerAdUnitID
        self.banner.rootViewController = self
        self.banner.load(GADRequest())
    }
    
    func showAlert(withTitle title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let dismissAction = UIAlertAction(title: "Dismiss", style: .destructive, handler: nil)
            alert.addAction(dismissAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension FriendlyChatViewController: UITableViewDelegate, UITableViewDataSource {
    // UITableViewDataSource protocol methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Dequeue cell
        let cell = self.clientTable.dequeueReusableCell(withIdentifier: "tableViewCell", for: indexPath)
        // Unpack message from Firebase DataSnapshot
        let messageSnapshot: FIRDataSnapshot! = self.messages[indexPath.row]
        guard let message = messageSnapshot.value as? [String: String] else { return cell }
        let name = message[Constants.MessageFields.name] ?? ""
        if let imageURL = message[Constants.MessageFields.imageURL] {
            if imageURL.hasPrefix("gs://") {
                FIRStorage.storage().reference(forURL: imageURL).data(withMaxSize: INT64_MAX) { (data, error) in
                    if let error = error {
                        print("Error downloading: \(error)")
                        return
                    }
                    DispatchQueue.main.async {
                        cell.imageView?.image = UIImage(data: data!)
                        cell.setNeedsLayout()
                    }
                }
            } else if let URL = URL(string: imageURL), let data = try? Data(contentsOf: URL) {
                cell.imageView?.image = UIImage(data: data)
            }
            cell.textLabel?.text = "sent by: \(name)"
        } else {
            let text = message[Constants.MessageFields.text] ?? ""
            cell.textLabel?.text = name + ": " + text
            cell.imageView?.image = UIImage(named: "ic_account_circle")
            if let photoURL = message[Constants.MessageFields.photoURL], let url = URL(string: photoURL), let data = try? Data(contentsOf: url) {
                cell.imageView?.image = UIImage(data: data)
            }
        }
        return cell
    }
}

extension FriendlyChatViewController: UITextFieldDelegate {
    // UITextFieldDelegate protocol methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text else { return true }
        textField.text = ""
        view.endEditing(true)
        let data  = [Constants.MessageFields.text: text]
        sendMessage(withData: data)
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        
        let newLength = text.characters.count + string.characters.count - range.length
        return newLength <= self.msglength.intValue // Bool
    }
}

extension FriendlyChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Image Picker
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let uid = FIRAuth.auth()?.currentUser?.uid else { return }
        
        // if it's a photo from the library, not an image from the camera
        if #available(iOS 8.0, *), let referenceURL = info[UIImagePickerControllerReferenceURL] as? URL {
            let assets = PHAsset.fetchAssets(withALAssetURLs: [referenceURL], options: nil)
            let asset = assets.firstObject
            asset?.requestContentEditingInput(with: nil) { [weak self] (contentEditingInput, info) in
                let imageFileURL = contentEditingInput?.fullSizeImageURL
                let filePath = "\(uid)/\(Int(Date.timeIntervalSinceReferenceDate * 1000))/\((referenceURL as AnyObject).lastPathComponent!)"
                guard let strongSelf = self else { return }
                strongSelf.storageRef.child(filePath).putFile(imageFileURL!, metadata: nil) { (metadata, error) in
                    if let error = error {
                        let nsError = error as NSError
                        print("Error uploading:\(nsError.localizedDescription)")
                        return
                    }
                    strongSelf.sendMessage(withData: [Constants.MessageFields.imageURL: strongSelf.storageRef.child((metadata?.path)!).description])
                }
            }
        } else {
            guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else { return }
            let imageData = UIImageJPEGRepresentation(image, 0.8)
            let imagePath = "\(uid)/\(Int(Date.timeIntervalSinceReferenceDate * 1000)).jpg"
            let metadata = FIRStorageMetadata()
            metadata.contentType = "image/jpeg"
            self.storageRef.child(imagePath).put(imageData!, metadata: metadata) { [weak self] (metadata, error) in
                if let error = error {
                    print("Error uploading: \(error)")
                    return
                }
                guard let strongSelf = self else { return }
                strongSelf.sendMessage(withData: [Constants.MessageFields.imageURL: strongSelf.storageRef.child((metadata?.path)!).description])
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
