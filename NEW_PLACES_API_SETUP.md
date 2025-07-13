# New Google Places API Setup Guide

## ✅ Code Updates Complete
Your PlaceService.swift has been updated to use the new Google Places API (New). The changes include:

### 1. Autocomplete API Changes
- **Old**: `https://maps.googleapis.com/maps/api/place/autocomplete/json`
- **New**: `https://places.googleapis.com/v1/places:autocomplete`
- **Method**: Changed from GET to POST with JSON body
- **Headers**: Added `X-Goog-Api-Key` and `Content-Type: application/json`

### 2. Place Details API Changes  
- **Old**: `https://maps.googleapis.com/maps/api/place/details/json`
- **New**: `https://places.googleapis.com/v1/places/{PLACE_ID}`
- **Headers**: Added `X-Goog-Api-Key` and `X-Goog-FieldMask`

## 🔧 Required Google Cloud Console Setup

### Step 1: Enable New Places API
1. Go to [Google Cloud Console APIs](https://console.cloud.google.com/apis/library)
2. Search for "Places API (New)"
3. Click on it and press "Enable"

### Step 2: Update API Key Restrictions (REQUIRED)
1. Go to [API Keys](https://console.cloud.google.com/apis/credentials)
2. Click on your API key
3. Under "Application restrictions":
   - Select "HTTP referrers"
   - Add `https://hushmap.app/*` as an authorized referrer
   - For development, add `http://localhost:*/*` (optional)
4. Under "API restrictions":
   - Add "Places API (New)" to the list of restricted APIs
   
> ⚠️ **CRITICAL SECURITY WARNING**: Unrestricted API keys will lead to unauthorized usage and additional billing charges. Google will send warning emails for unrestricted keys. See API_KEY_SECURITY.md for details.

### Step 3: Verify Old API Disable (Optional)
- You can now disable the legacy "Places API" since we're using the new one
- This won't affect your implementation

## 🧪 Testing the New Implementation

After enabling the new API, test by:
1. Opening the app
2. Tapping the Search button in the top menu
3. Typing a place name (e.g., "Preston")
4. You should see autocomplete suggestions without errors

## 📝 What Changed in Code

The main changes preserve the same interface but use the new API format:

- **Request Format**: Now uses JSON POST requests with proper headers
- **Response Parsing**: Updated to handle the new JSON structure
- **Field Names**: Updated to match new API field names (`displayName.text` vs `name`)
- **Location Data**: Updated path (`location.latitude` vs `geometry.location.lat`)

## 🎯 For Google Maps Platform Awards

This update demonstrates:
- **Modern API Usage**: Using the latest Google Places API
- **Best Practices**: Proper error handling and request formatting
- **Technical Excellence**: Professional API integration suitable for awards submission