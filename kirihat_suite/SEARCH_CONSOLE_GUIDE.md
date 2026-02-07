# Google Search Console Setup Guide

This guide will help you verify your ownership of `kirihat.com` and submit your sitemap to Google.

## Step 1: Add Property
1. Go to [Google Search Console](https://search.google.com/search-console).
2. Log in with your Google Account.
3. Click "Add Property" (top left dropdown).
4. Choose **URL Prefix** (easiest for now) or **Domain** (requires DNS change).
   - **Recommended**: Select **URL Prefix** and enter `https://kirihat.com`.

## Step 2: Verify Ownership
Google needs to know you own the site. The easiest way without accessing your domain registrar is the **HTML Tag** method.

1. In the verification options, scroll down to **HTML tag**.
2. Click to expand it. You will see a line of code like:
   `<meta name="google-site-verification" content="YOUR_CODE_HERE" />`
3. **Copy this tag.**

### Action Required
Once you have this tag, you can send it to me, and I will place it in your `index.html`. 
OR
You can paste it yourself:
- Open `static_site/index.html`.
- Paste the tag inside the `<head>` section.
- Open `customer_app/web/index.html`.
- Paste the tag inside the `<head>` section.

After updating the code:
1. Run `.\deploy_web.ps1` to deploy.
2. Go back to Search Console and click **Verify**.

## Step 3: Submit Sitemap
Once verified, you need to tell Google where your sitemap is.

1. In the Search Console sidebar, click **Sitemaps**.
2. In the "Add a new sitemap" section, enter:
   `sitemap.xml`
3. Click **Submit**.

Google will now see `https://kirihat.com/sitemap.xml` and start indexing all your pages (About Us, Policies, etc.).

## Step 4: Indexing Request (Optional)
To speed things up:
1. Paste `https://kirihat.com/` in the top search bar (Inspect any URL).
2. Wait for it to load data.
3. Click **Request Indexing**.
