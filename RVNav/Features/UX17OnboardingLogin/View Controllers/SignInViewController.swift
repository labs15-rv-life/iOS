//
//  SignInViewController.swift
//  RVNav
//
//  Created by Jake Connerly on 12/16/19.
//  Copyright © 2019 RVNav. All rights reserved.
//

import UIKit
import FirebaseAnalytics

class SignInViewController: ShiftableViewController {

    // MARK: - IBOutlets & Properties

    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var backgroundImageContainerView: UIView!
    @IBOutlet weak var googleSignInButton: UIButton!
    @IBOutlet weak var facebookSignInButton: UIButton!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!
    
    var networkController: NetworkController?
    
    // MARK: - View LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UISetup()
        tapOutsideToDismissKeyBoard()
    }
    
    // MARK: - IBActions & Methods
    
    private func UISetup() {
        
        googleFacebookButtonUISetup()
        signInButtonButtonUISetup()
    }
    
    private func googleFacebookButtonUISetup() {
        //Google Button UI Set Up
        googleSignInButton.layer.cornerRadius = 4
        googleSignInButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
        googleSignInButton.layer.borderWidth = 0.2
        
        //Facebook Button UI Set Up
        facebookSignInButton.layer.cornerRadius = 4
        facebookSignInButton.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
        googleSignInButton.layer.borderWidth = 0.2
    }
    
    private func signInButtonButtonUISetup() {
        signInButton.layer.borderWidth = 0.4
        signInButton.layer.cornerRadius = 4
        if let email = emailTextField.text,
                !email.isEmpty,
            let password = passwordTextField.text,
            !password.isEmpty
        {
            signInButton.isEnabled = true
            signInButton.backgroundColor = .babyBlue
        } else {
            signInButton.isEnabled = false
            signInButton.backgroundColor = .clear
            
        }
    }
    
    private func tapOutsideToDismissKeyBoard() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func signInButtonTapped(_ sender: UIButton) {
        
        guard let email = emailTextField.text,
        let password = passwordTextField.text,
        !email.isEmpty,
        !password.isEmpty else { return }
        
        let signInInfo = SignInInfo(username: email, password: password)
        networkController?.signIn(with: signInInfo) { (error) in
            if let error = error {
                NSLog("Error signing up: \(error)")
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Username or Password incorrect", message: "Please try again.", preferredStyle: .alert)
                    let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(alertAction)

                    self.present(alert, animated: true)
                }
            }
            guard let message = self.networkController?.result?.message else { return }
            print(message)
            if self.networkController?.result?.token != nil {
                Analytics.logEvent("login", parameters: nil)
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                                    }
            }
        }
    }
}

extension SignInViewController {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case emailTextField:
            if let email = emailTextField.text,
                !email.isEmpty {
                signInButtonButtonUISetup()
                dismissKeyboard()
                passwordTextField.becomeFirstResponder()
                return true
            } else {
                signInButtonButtonUISetup()
                return false
            }
        case passwordTextField:
            if let password = passwordTextField.text,
                !password.isEmpty {
                signInButtonButtonUISetup()
                dismissKeyboard()
                signInButton.becomeFirstResponder()
                return true
            } else {
                return false
            }
        default:
            return true
        }
    }
}