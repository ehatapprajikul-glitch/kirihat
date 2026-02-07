# Kirihat Suite Deployment Guide

This guide explains how to compile and deploy the different components of the Kirihat Suite.

## Project Structure
- **Admin Portal**: Located in `admin_portal/`. Hosted at `kiri-hat-portal.web.app`.
- **Customer App**: Located in `customer_app/`. Hosted at `kiri-hat-live.web.app/app/`.
- **Static Site**: Located in `static_site/`. Hosted at `kiri-hat-live.web.app` (root).

## Prerequisites
- Flutter SDK installed and accessible in terminal.
- Firebase CLI installed and logged in (`firebase login`).
- PowerShell (for running the automated script).

---

## Method 1: Automated Deployment (Recommended)

There is a PowerShell script `deploy_web.ps1` in the root directory that handles the entire build and staging process for you.

1. Open a terminal in the project root (`E:\Developing\new\kirihat_suite`).
2. Run the script:
   ```powershell
   .\deploy_web.ps1
   ```
   This script will:
   - Build the Customer App with the correct configuration.
   - Prepare the `dist` folder.
   - Copy the Static Site and Customer App files to `dist`.
   - Build the Admin Portal.
   - Deploy everything to Firebase.

---

## Method 2: Manual Deployment

If you need to deploy specific components individually, follow these steps.

### 1. Admin Portal

**Compile:**
1. Navigate to the admin portal directory:
   ```powershell
   cd admin_portal
   ```
2. Build for web:
   ```powershell
   flutter build web --release
   ```

**Deploy:**
1. Return to the root directory:
   ```powershell
   cd ..
   ```
2. Deploy only the portal:
   ```powershell
   firebase deploy --only hosting:portal
   ```

### 2. Customer App

The Customer App requires special handling because it is hosted in a subdirectory (`/app/`).

**Compile:**
1. Navigate to the customer app directory:
   ```powershell
   cd customer_app
   ```
2. Build for web with the base-href flag:
   ```powershell
   flutter build web --release --base-href "/app/"
   ```

**Stage Files:**
The build output must be moved to the distribution folder.
1. Return to the root directory.
2. Provide a clean target folder:
   - Ensure `dist/customer_site/app` exists.
   - Clear old files if necessary.
3. Copy contents from `customer_app/build/web/*` to `dist/customer_site/app/`.

**Deploy:**
1. From the root directory, deploy the customer hosting target:
   ```powershell
   firebase deploy --only hosting:customer
   ```

### 3. Static Site

The static site files are deployed alongside the Customer App.

**Stage Files:**
1. Copy all files from `static_site/*` to `dist/customer_site/`.
   - This should place files like `index.html` (the landing page) directly in `dist/customer_site/`.

**Deploy:**
1. This is deployed as part of the customer target:
   ```powershell
   firebase deploy --only hosting:customer
   ```

---

## Troubleshooting

- **Favicon/Cache Issues**: If you update images or icons and don't see them change, it's often a browser cache issue. You can force a refresh by pressing `Ctrl + F5` or adding a version query string (e.g., `?v=2`) to the file reference in `index.html`.
- **Missing Directory Error**: If `firebase deploy` says a directory does not exist, ensure you have run the `flutter build web` command for that project first.
