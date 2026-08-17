# Contributing to FPSWatcher

First off, thank you for considering contributing to FPSWatcher! It's people like you that make open-source software such a great community.

## How Can I Contribute?

### Reporting Bugs
If you find a bug in the source code or a mistake in the documentation, you can help us by submitting an issue to our GitHub Repository. Even better, you can submit a Pull Request with a fix.

### Suggesting Enhancements
If you have an idea for an enhancement, please submit an issue on our GitHub repository. Provide a clear and descriptive title and explain the requested feature or enhancement in detail.

### Pull Requests
1. **Fork the repository** and create your branch from `main`.
2. **If you've added code** that should be tested, add tests.
3. **Ensure the test suite passes**.
4. **Make sure your code lints**.
5. **Issue that pull request!**

## Development Setup

FPSWatcher is a hybrid application built using Flutter (UI) and Rust (Native Core).

### Prerequisites
- **Flutter SDK** (Version 3.4.0 or higher)
- **Rust Toolchain** (rustup, cargo)
- **Android Studio** or **VS Code** with appropriate plugins.
- **NDK** (For compiling the Rust code for Android)

### Compiling the Rust Core
If you make changes in the `rust` folder, you need to compile the native libraries before running the Flutter app.
You can use `cargo` to build the required targets or use the provided build scripts.

## Styleguides

### Git Commit Messages
- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

We look forward to your contributions!
