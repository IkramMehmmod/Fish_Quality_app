# Fish Quality Detector

Fish Quality Detector is a Flutter app that uses machine learning to analyze the freshness quality of fish from images. Capture or select a photo, and the app will predict whether the fish is Fresh, Medium, or Rotten, along with a confidence score.

## Features

- 📸 Capture or select a fish image from your gallery or camera
- 🤖 On-device machine learning (TensorFlow Lite)
- 🟢🟠🔴 Predicts quality: Fresh, Medium, or Rotten
- 📊 Shows confidence level and detailed breakdown
- ✨ Animated, modern, and user-friendly interface
- 📤 Share results with others

## Screenshots

<!-- Add your screenshots to the assets folder and reference them below -->
<p align="center">
  <img src="assets/screenshot1.png" alt="Home Screen" width="250"/>
  <img src="assets/screenshot2.png" alt="Image Preview" width="250"/>
  <img src="assets/screenshot3.png" alt="Result Screen" width="250"/>
</p>

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install)
- A device or emulator

### Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/IkramMehmmod/Fist_Quality_app.git
   cd Fist_Quality_app
   ```

2. **Install dependencies:**
   ```sh
   flutter pub get
   ```

3. **Run the app:**
   ```sh
   flutter run
   ```

## Usage

1. Launch the app.
2. Capture a new photo or select one from your gallery.
3. Wait for the app to analyze the image.
4. View the predicted quality and confidence.
5. Share the results or analyze another fish.

## Model

- The app uses a TensorFlow Lite model (`assets/fish_model.tflite`) for on-device inference.

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](LICENSE)

---

> **Note:** If you want screenshots to appear in the README, add them to the `assets` folder and update the image paths above.
