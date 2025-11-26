# My Account Team - Lightning Web Component

A Salesforce Lightning Web Component (LWC) designed for B2B Commerce websites that displays Account team members and the Account owner on the /my-account page.

## Features

- 📋 **Team Display**: Shows all Account team members and the Account owner
- 👤 **Member Information**: Displays full name, title, and email address for each team member
- 🖼️ **Profile Photos**: Supports CMS-stored images referenced by ContentKey
- 📧 **Email Integration**: Individual mailto: links for each member
- 📨 **Contact Team Button**: Single button to email all team members simultaneously
- 🎨 **Responsive Design**: Mobile-friendly grid layout
- ⚡ **Performance**: Cacheable Apex methods for optimal performance

## Components

### Apex Controller
- **File**: `force-app/main/default/classes/MyAccountTeamController.cls`
- **Purpose**: Fetches Account owner and team members for the current user's account
- **Methods**:
  - `getAccountTeamMembers()`: Returns list of team members with contact info

### Lightning Web Component
- **Location**: `force-app/main/default/lwc/myAccountTeam/`
- **Files**:
  - `myAccountTeam.html` - Component template
  - `myAccountTeam.js` - JavaScript controller
  - `myAccountTeam.css` - Component styling
  - `myAccountTeam.js-meta.xml` - Component metadata

## Prerequisites

Before deployment, ensure you have:

1. **Custom Field** (if using CMS photos):
   - Create a custom field `ContentKey__c` on the User object
   - Type: Text
   - Purpose: Stores the CMS content key for user profile photos

2. **Account Team Setup**:
   - Account Team members should be configured in Salesforce
   - Team members should have valid email addresses

## Deployment

### Using Salesforce CLI

1. **Authenticate to your org**:
   ```bash
   sfdx auth:web:login -a myOrg
   ```

2. **Deploy the components**:
   ```bash
   sfdx force:source:deploy -p force-app -u myOrg
   ```

### Using VS Code

1. Open the project in VS Code with Salesforce Extensions
2. Right-click on `force-app` folder
3. Select "Deploy Source to Org"

## Adding to Experience Cloud Site

1. Navigate to **Experience Builder** for your B2B Commerce site
2. Go to the **/my-account** page
3. Drag and drop the **My Account Team** component onto the page
4. Save and publish the site

## Configuration

### CMS Image Integration

The component expects images stored in CMS. Update the `getCMSImageUrl()` method in `myAccountTeam.js` if your CMS URL structure differs:

```javascript
getCMSImageUrl(contentKey) {
    // Adjust based on your CMS configuration
    return `/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=${contentKey}`;
}
```

### Customization Options

- **Header Text**: Modify "My Team" in `myAccountTeam.html`
- **Styling**: Update colors and spacing in `myAccountTeam.css`
- **Button Label**: Change "Contact My Team" text in the template
- **Card Layout**: Adjust grid columns in CSS (default: 300px min-width)

## User Object Fields Used

The component queries the following User fields:
- `Name` - Team member's full name
- `Title` - Job title
- `Email` - Email address
- `ContentKey__c` - Custom field for CMS image reference (optional)

## Security

- Component uses `with sharing` to enforce record-level security
- Only shows team members for the current user's account
- Requires users to be associated with an Account

## Browser Compatibility

- Supports all modern browsers (Chrome, Firefox, Safari, Edge)
- Mobile responsive design
- Email client integration uses standard `mailto:` protocol

## Troubleshooting

### No team members showing
- Verify the user is associated with an Account
- Check that Account Team is configured for the account
- Ensure team members have the required fields populated

### Images not loading
- Verify `ContentKey__c` field exists on User object
- Check CMS content key values are correct
- Update `getCMSImageUrl()` method with correct CMS path

### Email button not working
- Ensure team members have email addresses
- Check browser allows `mailto:` links
- Verify popup blockers aren't interfering

## License

This component is provided as-is for use in Salesforce B2B Commerce implementations.