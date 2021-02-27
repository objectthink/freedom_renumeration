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
    func getChipData() -> [(Int32, String, String)]
    {
        //return chip data
        return [
            (0x9f12, "Application Preferred Name"   ,"MasterCard"),
            (0x5f20, "Cardholder Name"              , "James Smith"),
            (0x5f28, "Issuer Country Code"          , "0840")
        ]
    }
}

protocol ProcessTransactionDelegate
{
}

class Processor
{
    var delegate: ProcessTransactionDelegate?
    
}

protocol DataServiceDelegateProtocol
{
}

protocol DataServiceProtocol
{
    func startTransaction(TransactionAmountInCents amount: Int) -> [(Int32, String, String)]
    func processTransaction()
}

class DataService: DataServiceProtocol
{
    var delegate: DataServiceDelegateProtocol?
    var _transactionAmountInCents: Int?
    
    //take   transaction amount in cents
    //return tuple of chip data
    func startTransaction(TransactionAmountInCents amount: Int) -> [(Int32, String, String)] {
        
        //set transaction amount
        _transactionAmountInCents = amount
        
        //return chip data returned from card reader
        return (_cardReader?.getChipData())!
    }
    
    func processTransaction() {
        
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
    
    var _dataService: DataService?
    
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
        
        //validate  input here
        
        //start transaction
        let amount = Float(_amountText.text!)
        let amountAsCents: Int = Int(amount! * Float(100))
        
        //testing
        print("\(amountAsCents)")

        //call start transaction and update ui
        let chipData = _dataService?.startTransaction(TransactionAmountInCents: amountAsCents)
        
        chipData!.forEach { (tag, description, value) in
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
            message: "Is this information correct?\namount: \(amount!)",
            preferredStyle: UIAlertController.Style.alert)

        prompt.addAction(
            UIAlertAction(
                title: "Ok",
                style: .default,
                handler: { (action: UIAlertAction!) in
                    print("OK")
                    
                    //process transaction
                    self._dataService?.processTransaction()
                }))

        prompt.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel,
                handler: { (action: UIAlertAction!) in
                    print("CANCEL")
                }))

        present(prompt, animated: true, completion: nil)
    }
    
}

