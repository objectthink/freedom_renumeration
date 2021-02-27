//
//  ViewController.swift
//  freedom_renumeration
//
//  Created by stephen eshelman on 2/27/21.
//

import UIKit

// MARK: - DATA SERVICE
class CardReader
{
    //return chip data
    //assume that the data is cached and that this is a short, synchronous operation
    func getChipData() -> [(tag: Int32, description: String, value: String)]
    {
        //return chip data
        return [
            (0x9f12, "Application Preferred Name"   , "MasterCard"),
            (0x5f20, "Cardholder Name"              , "James Smith"),
            (0x5f28, "Issuer Country Code"          , "0840")
        ]
    }
}

class Processor
{
    private func containsTag(chipData: [(Int32, String, String)], tag: Int32) -> Bool
    {
        var found: Bool = false
        chipData.forEach
        { (tagValue, _, _) in
            if tagValue == tag
            {
                found = true
            }
        }
        
        return found
    }
    
    func processTransaction(transaction: (amount: Int, chipData: [(Int32, String, String)] ), completion: @escaping (Bool)->()) -> Bool
    {
        //did we get the right number of tags?
        guard transaction.chipData.count == 3 else {
            completion(false)
            return false
        }
        
        //did we get the APN
        guard containsTag(chipData: transaction.chipData, tag: 0x9f12) else {
            completion(false)
            return false
        }
        
        //did we get the cardholder name
        guard containsTag(chipData: transaction.chipData, tag: 0x5f20) else {
            completion(false)
            return false
        }
        
        //did we get the country code
        guard containsTag(chipData: transaction.chipData, tag: 0x5f28) else {
            completion(false)
            return false
        }
        
        let seconds = 5.0
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds)
        {
            completion(true)
        }
        
        return true
    }
}

protocol DataServiceDelegateProtocol
{
    func dataServiceStatus(status: String)
}

protocol DataServiceProtocol
{
    func startTransaction(TransactionAmountInCents amount: Int) -> (amount: Int, chipData: [(Int32, String, String)])
    func processTransaction(transaction: (amount: Int, chipData: [(Int32, String, String)] ), completion: @escaping (Bool)->()) -> Bool
}

class DataService: DataServiceProtocol
{
    var delegate: DataServiceDelegateProtocol?
    var _transactionAmountInCents: Int?
    
    //take   transaction amount in cents
    //return tuple of amount and chip data
    func startTransaction(TransactionAmountInCents amount: Int) -> (amount: Int, chipData: [(Int32, String, String)]) {
        delegate?.dataServiceStatus(status: "start transaction")
        
        //set transaction amount
        _transactionAmountInCents = amount
        
        //return chip data returned from card reader
        return (amount: _transactionAmountInCents!, chipData: (_cardReader?.getChipData())!)
    }
    
    func processTransaction(transaction: (amount: Int, chipData: [(Int32, String, String)]), completion: @escaping (Bool)->()) -> Bool
    {
        delegate?.dataServiceStatus(status: "process transaction")
        let processor = Processor()
        
        return processor.processTransaction(transaction: transaction, completion: completion)
    }
    
    var _cardReader: CardReader?
    var _processor: Processor?
    
    init()
    {
        _cardReader = CardReader()
        _processor = Processor()
    }
}

//MARK: - VIEW CONTROLLER
class ViewController: UIViewController, UITextFieldDelegate, DataServiceDelegateProtocol {
    @IBOutlet weak var _amountText: UITextField!
    @IBOutlet weak var _submitButton: UIButton!
    @IBOutlet weak var _applicationPreferredNameLabel: UILabel!
    @IBOutlet weak var _nameLabel: UILabel!
    @IBOutlet weak var _countryLabel: UILabel!
    @IBOutlet weak var _dataServiceStatus: UILabel!
    @IBOutlet weak var _busyIndicator: UIActivityIndicatorView!
    
    var _dataService: DataService?
    
    func dataServiceStatus(status: String) {
        _dataServiceStatus.text = status
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        //set the amount text field delegate and set keyboard type
        _amountText.delegate = self
        
        //create data service and set delegate
        _dataService = DataService()
        _dataService?.delegate = self
    }
    
    //called as textfield is updated
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        //control access to the submit button
        _submitButton.isEnabled = string != "" || string == "" && textField.text!.count > 1
        
        //review values
        print("textField: \(textField.text!)")
        print("string: \(string)")
        
        return true
    }
    
    @IBAction func submitClicked(_ sender: UIButton) {
        //hide keyboard and disable submitbutton
        _amountText.resignFirstResponder()
        _submitButton.isEnabled = false
        
        //start transaction
        let amount = Float(_amountText.text!)
        let amountAsCents: Int = Int(amount! * Float(100))
        
        //testing
        print("\(amountAsCents)")

        //call start transaction and update ui
        let returnData = _dataService?.startTransaction(TransactionAmountInCents: amountAsCents)
        
        returnData?.chipData.forEach { (tag, description, value) in
            if(tag == 0x9f12)
            {
                _applicationPreferredNameLabel.text = value
            }
            
            if tag == 0x5f20
            {
                _nameLabel.text = value
            }
            
            if tag == 0x5f28
            {
                _countryLabel.text = value
            }
        }
        
        let prompt = UIAlertController(
            title: "Send",
            message: "Is this information correct?\namount: \(amount!)\nname:\(_nameLabel.text!)",
            preferredStyle: UIAlertController.Style.alert)

        prompt.addAction(
            UIAlertAction(
                title: "Ok",
                style: .default,
                handler: { (action: UIAlertAction!) in
                    print("OK")
                    
                    //start spinner and disable amount field
                    self.disableForm(disposition: true)
                    self._busyIndicator.startAnimating()
                    
                    //process transaction
                    //invalid transaction will call completion(false)
                    _ = self._dataService?.processTransaction(transaction: returnData!)
                    {success in
                        print("\(success)")
                        
                        self._busyIndicator.stopAnimating()
                        
                        var promptText = ""
                        if success
                        {
                            promptText = "was successful"
                        }
                        else
                        {
                            promptText = "failed"
                        }
                        
                        let alert = UIAlertController(
                            title: "Request status",
                            message: "Your request \(promptText)",
                            preferredStyle: UIAlertController.Style.alert)
                        
                        alert.addAction(
                            UIAlertAction(
                                title: "Ok",
                                style: .default,
                                handler: { (action: UIAlertAction!) in
                                    print("OK")
                                }))
                            
                        self._busyIndicator.stopAnimating()
                        
                        self.present(alert, animated: true, completion: nil)
                        
                        self.clearForm()
                        self.disableForm(disposition: false)
                    }
                }))

        prompt.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel,
                handler: { (action: UIAlertAction!) in
                    print("CANCEL")
                    self.clearForm()
                }))

        present(prompt, animated: true, completion: nil)
    }
    
    func clearForm()
    {
        _amountText.text = ""
        _applicationPreferredNameLabel.text = ""
        _countryLabel.text = ""
        _nameLabel.text = ""
    }
    
    func disableForm(disposition: Bool)
    {
        _amountText.isEnabled = !disposition
    }
    
}

