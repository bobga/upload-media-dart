# Identity Verification Flutter Widget

This Flutter widget provides a user interface for identity verification through various methods like selfie, mobile OTP, and email verification.

## Overview

The widget consists of three main tabs: Selfie, Mobile, and Email. Each tab handles a different method of identity verification.

### Selfie Tab

- Allows users to upload identification documents and take a selfie video.
- Provides a submit button for verification.

### Mobile Tab

- Requests a one-time password (OTP) sent to the user's phone number for verification.
- Allows resending OTP and verification.

### Email Tab

- Requires users to click a verification link sent to their email.
- Provides an option to resend the verification link.

## Usage

1. Include the `IdentityVerificationWidget` in your Flutter app.
2. Customize the widget as needed, including handling verification logic and UI elements.
3. Run your Flutter app on a device or emulator.

## Example

```dart
import 'package:flutter/material.dart';
import 'identity_verification_widget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Identity Verification Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: IdentityVerificationWidget(),
    );
  }
}
```
## Contributing

Contributions are welcome. Please submit bug reports, feature requests, or pull requests through GitHub issues and pull requests.

## License

This project is licensed under the MIT License.
