//
//  ViewController.swift
//  freedom_renumeration
//
//  Created by stephen eshelman on 2/27/21.
//

import UIKit

typealias ChipData = [(tag: Int32, description: String, value: String)]
typealias Transaction = (amount: Int, chipData: ChipData)

// MARK: - String extension to validate for number
extension String {
     struct NumFormatter {
         static let instance = NumberFormatter()
     }

     var doubleValue: Double? {
         return NumFormatter.instance.number(from: self)?.doubleValue
     }

     var integerValue: Int? {
         return NumFormatter.instance.number(from: self)?.intValue
     }
}

// MARK: - CARD READER
///class CardReader
///mock card reader
class CardReader
{
    //returns chip data as an array of tuples of ( In32, String, String ) ]
    //assume that the data is cached and that this is a short, synchronous operation
    func getChipData() -> ChipData
    {
        //return chip data
        return [
            (0x9f12, "Application Preferred Name"   , "MasterCard"),
            (0x5f20, "Cardholder Name"              , "James Smith"),
            (0x5f28, "Issuer Country Code"          , "0840")
        ]
    }
}

// MARK: - PAYMENT PROCESSOR
///class Processor
///mock payment processor
class Processor
{
    //returns true if the passed tag is found in the passed tuple
    func containsTag(chipData: ChipData, tag: Int32) -> Bool
    {
        var found: Bool = false
        
        //check array of tuples for passed tag
        for chipRecord in chipData
        {
            if chipRecord.tag == tag
            {
                found = true
            }
        }
        
        return found
    }
    
    /// process a payment transaction
    /// - Parameter transaction: tuple( amount, chipData)
    /// - Parameter completion: escaping completion handler that takes bool
    /// - Returns: true if valid transaction, otherwise false
    func processTransaction(transaction: Transaction, completion: @escaping (Bool)->()) -> Bool
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
        
        //simulate network processor request
        let seconds = 5.0
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds)
        {
            completion(true)
        }
        
        return true
    }
}

// MARK: - DATASERVICE
/// data service delegate protocol
/// could be used to send processing status messages to client
protocol DataServiceDelegateProtocol
{
    /// call delegate with status string
    /// - Parameter status string
    func dataServiceStatus(status: String)
}

/// data service protocol
/// has-a card reader and transaction processor
protocol DataServiceProtocol
{
    /// start a transaction
    /// - Parameter TransactionAmountInCents transaction amount in cents
    /// - Returns: tuple of amount and chipdata which is array of tuple ( tag, string, string ) acquired from card reader
    func startTransaction(TransactionAmountInCents amount: Int) -> (amount: Int, chipData: ChipData)

    /// process transaction using transaction processor
    /// - Parameter transaction
    /// - Parameter escaping completion handler
    func processTransaction(transaction: Transaction, completion: @escaping (Bool)->()) -> Bool
}

/// class DataService
class DataService: DataServiceProtocol
{
    var delegate: DataServiceDelegateProtocol?
    var _transactionAmountInCents: Int?
    
    //take   transaction amount in cents
    //return tuple of amount and chip data
    func startTransaction(TransactionAmountInCents amount: Int) -> (amount: Int, chipData: ChipData)
    {
        delegate?.dataServiceStatus(status: "start transaction")
        
        //set transaction amount
        _transactionAmountInCents = amount
        
        //return chip data returned from card reader
        return (amount: _transactionAmountInCents!, chipData: (_cardReader?.getChipData())!)
    }
    
    //process a transaction though the transaction processor
    func processTransaction(transaction: Transaction, completion: @escaping (Bool)->()) -> Bool
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
    
    /// data service status
    /// used to show processing status messages
    /// NOT USED
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
        
        //only enable submit button if valid double
        if let doubleValue = string.doubleValue
        {
            print("is valid: \(doubleValue)")
        }
        else
        {
            _submitButton.isEnabled = false
        }
        
        //review values
        print("textField: \(textField.text!)")
        print("string: \(string)")
        
        return true
    }
    
    /// submit clicked
    /// hide keyboard and disable submit button
    /// get chip data from data service and update ui
    /// prompt user and process transaction if ok
    /// start spinner, call through data service to process transaction
    /// stop spinner in process transaction completion handler
    /// alert user of transaction status
    /// setup form for next transaction
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
                title: "Yes",
                style: .default,
                handler: { (action: UIAlertAction!) in
                    print("YES")
                    
                    //start spinner and disable amount field
                    self.disableForm(disposition: true)
                    self._busyIndicator.startAnimating()
                    
                    //process transaction
                    //invalid transaction will call completion(false)
                    _ = self._dataService?.processTransaction(transaction: returnData!)
                    { success in
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
                            
                        // stop spinner
                        self._busyIndicator.stopAnimating()
                        
                        // show alert with tranaction request status
                        self.present(alert, animated: true, completion: nil)
                        
                        // setup form for next transaction
                        self.clearForm()
                        self.disableForm(disposition: false)
                    }
                }))

        prompt.addAction(
            UIAlertAction(
                title: "No",
                style: .cancel,
                handler: { (action: UIAlertAction!) in
                    print("NO")
                    self.clearForm()
                }))

        present(prompt, animated: true, completion: nil)
    }
    
    /// clear the form
    func clearForm()
    {
        _amountText.text = ""
        _applicationPreferredNameLabel.text = ""
        _countryLabel.text = ""
        _nameLabel.text = ""
    }
    
    /// disable the form
    func disableForm(disposition: Bool)
    {
        _amountText.isEnabled = !disposition
    }
    
}

