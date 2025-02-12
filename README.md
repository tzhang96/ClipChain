# ClipChain

A modern video sharing platform built with Flutter and Firebase, featuring AI-powered video analysis using Google's Gemini API.

## Features

- **Video Sharing**: Upload and share videos with automatic thumbnail generation
- **AI Video Analysis**: Automatic analysis of video content using Google's Gemini API
  - Content summaries
  - Style detection
  - Mood analysis
  - Visual element identification
- **Video Chains**: Create and share curated collections of related videos
- **Social Features**: Like videos and chains, user profiles
- **Real-time Updates**: Live status updates for video processing and analysis

## Setup

### Prerequisites

- Flutter SDK (^3.6.0)
- Firebase CLI
- Node.js (v18)
- PowerShell (for Windows) or Bash (for Unix-based systems)

### Environment Setup

1. Clone the repository
2. Set up Firebase:
   ```powershell
   firebase login
   firebase init
   ```

3. Create environment files:
   - In root directory: `.env`
   - In functions directory: `functions/.env`

   Example `.env` contents:
   ```
   GEMINI_API_KEY=your_gemini_api_key_here
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_API_KEY=your_api_key
   CLOUDINARY_API_SECRET=your_api_secret
   CLOUDINARY_UPLOAD_PRESET=your_upload_preset
   ```

4. Install dependencies:
   ```powershell
   # Flutter dependencies
   flutter pub get

   # Firebase Functions dependencies
   cd functions
   npm install
   ```

### Firebase Configuration

1. Set up Firebase Functions configuration:
   ```powershell
   firebase functions:config:set gemini.api_key="$env:GEMINI_API_KEY"
   ```

2. Deploy Firebase Functions:
   ```powershell
   firebase deploy --only functions
   ```

## Development

### Running Tests

```powershell
cd functions
npm run test
```

### Local Development

1. Start Firebase emulators:
   ```powershell
   firebase emulators:start
   ```

2. Run the Flutter app:
   ```powershell
   flutter run
   ```

## Architecture

### Video Analysis Pipeline

1. Video Upload:
   - Videos are uploaded to Cloudinary
   - Thumbnails are automatically generated
   - Video document created in Firestore

2. Analysis Trigger:
   - Firebase Function triggered on video creation
   - Video downloaded and processed by Gemini API
   - Analysis results stored in video document

3. Analysis States:
   - `pending`: Initial state during processing
   - `completed`: Analysis successfully completed
   - `failed`: Analysis encountered an error

### Data Model

- **Videos**: Store video metadata and analysis results
- **Users**: User profiles and authentication data
- **Chains**: Curated collections of videos
- **Likes**: Track user interactions

## Troubleshooting

### Common Issues

1. Video Analysis Failures:
   - Ensure Gemini API key is correctly set in Firebase config
   - Check video format compatibility (MP4 recommended)
   - Verify Firebase Functions deployment

2. Environment Setup:
   - Ensure all environment variables are correctly set
   - Verify Firebase project configuration
   - Check Node.js version compatibility

## Recent Updates

- Added Google Gemini API integration for video analysis
- Implemented real-time analysis status tracking
- Added support for video reanalysis
- Enhanced error handling and status reporting
- Updated to use `gemini-2.0-flash` model for improved analysis

## License

This project is licensed under the MIT License - see the LICENSE file for details. 