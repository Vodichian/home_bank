# Home Bank

A Flutter-based home banking client application designed for managing finances, particularly for educational purposes within a family.

## Project Overview

This application allows users to interact with a corresponding `bank_server` (expected to be running separately) to perform various banking operations. It features user authentication (including QR code login), transaction management, and administrative functions for transaction approvals.

## Features

*   User login with username/password and QR code scanning.
*   Account balance viewing.
*   Funds transfer and withdrawal (pending approval).
*   Admin approval system for sensitive transactions, also supporting QR code for admin login.
*   Management of users and merchants (features may vary based on server capabilities).

## Getting Started

This is a Flutter project. To run this application, you will need to have Flutter installed on your system.

1.  **Clone the repository.**
2.  **Ensure the `bank_server` is running** and accessible to this client application. Configuration for the server connection is managed within the app.
3.  **Install dependencies:**
    
```bash
    flutter pub get
```
4.  **Run the application:**
    
```bash
    flutter run
```

## Application Signing and Trust (for Windows MSIX)

The Windows MSIX distribution of this application is signed. To ensure your system trusts the application, you may need to install the public certificate.

*   **Download and install the public certificate:** [vodichian_public.cer](./certs/vodichian_public.cer)

    To install:
    1.  Download the `.cer` file.
    2.  Double-click the file.
    3.  Click "Install Certificate...".
    4.  Choose "Current User" or "Local Machine" (Local Machine typically requires admin rights and installs for all users).
    5.  Select "Place all certificates in the following store".
    6.  Click "Browse..." and select "Trusted Root Certification Authorities".
    7.  Click "OK", then "Next", then "Finish".
    8.  Acknowledge any security warnings if they appear.

## Development Resources

For general Flutter development help:

*   [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
*   [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
*   [Online documentation](https://docs.flutter.dev/), which offers tutorials, samples, guidance on mobile development, and a full API reference.

