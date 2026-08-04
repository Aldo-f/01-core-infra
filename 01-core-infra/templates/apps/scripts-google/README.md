# 06-apps-scripts-google — Google Apps Script reminder system
# Managed by 01-core-infra install.sh
# Wijzig ALLEEN via templates/infra/06-apps-scripts-google/

# Google Apps Scripts (FollowUpReminder + LabelReminder) are deployed via Google Cloud
# and accessed through the Google Apps Script API using clasp CLI.

## Prerequisites
- Google Cloud project with Apps Script API enabled
- OAuth 2.0 Desktop App credentials
- Callback URL configured in Google Cloud Console

## Deployment Commands

### Initial Setup (one-time)
```bash
# Clone the repository
git clone git@github.com:Aldo-f/script.google.git 06-apps-script-google
cd 06-apps-script-google

# Install dependencies
npm install

# Install clasp globally (requires sudo)
sudo npm install -g @google/clasp

# Authenticate globally (creates ~/.clasprc.json)
npm run login
# or: clasp login
```

### Configure Callback URL
**IMPORTANT**: In Google Cloud Console → OAuth 2.0 Client IDs → Authorized redirect URIs:
- Add: `http://192.168.0.5` (your server IP)
- Do NOT use `localhost` for headless servers

### Deploy Scripts
```bash
# Validate code before pushing
npm run validate

# Push FollowUpReminder
npm run push:followup
# or: cd FollowUpReminder && clasp push --force

# Push LabelReminder
npm run push:label
# or: cd LabelReminder && clasp push --force
```

### Available npm Scripts
```bash
npm run validate       # Validate all .gs files
npm run push:followup  # Push FollowUpReminder to Google
npm run push:label     # Push LabelReminder to Google
npm run pull:followup  # Pull FollowUpReminder from Google
npm run pull:label     # Pull LabelReminder from Google
npm run login          # Authenticate clasp globally
npm run logout         # Logout clasp
npm run list           # List clasp projects
```

## Key Files
- `FollowUpReminder/.clasp.json` - FollowUpReminder clasp config
- `LabelReminder/.clasp.json` - LabelReminder clasp config
- `shared/AIProviders.gs` - Shared AI provider code
- `scripts/validate.js` - Syntax validation script

## Troubleshooting

### "Error retrieving access token"
Run `npm run login` to re-authenticate globally.

### "Project settings not found"
Ensure you're in the correct project directory (FollowUpReminder/ or LabelReminder/) or run `clasp create` first.

### Headless Server Issues
- Use global authentication (`npm run login`) not per-project
- Configure OAuth redirect URI to your server IP, not localhost
- The clasp login URL will show a port - open it in your browser from any machine on the network

## Google Cloud Setup
1. Go to Google Cloud Console
2. Create/select project
3. Enable Google Apps Script API
4. Create OAuth 2.0 Desktop App credentials
5. Add authorized redirect URI: `http://192.168.0.5`
6. Note: clasp uses its own client ID by default, but you can use your own with `--creds`

## Deployment URLs
After deployment, scripts are accessible at:
- FollowUpReminder: `https://script.google.com/macros/s/<SCRIPT_ID>/exec`
- LabelReminder: `https://script.google.com/macros/s/<SCRIPT_ID>/exec`

Get script IDs with: `clasp list` in each project directory.