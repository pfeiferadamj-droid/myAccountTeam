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

1. **Custom Object**: Create a custom object `My_Account_Team_Member__c`
   - This object is used instead of the standard `AccountTeamMember` because the standard object is not accessible from Experience Cloud sites
   - **Required fields:**
     - `Account__c` (Master-Detail to Account)
     - `Team_Member_User__c` (Lookup to User)
     - `Member_Email__c` (Text, 255) - Stores team member's email address
     - `Member_Title__c` (Text, 255) - Stores team member's job title
   - **Optional fields:**
     - `Role__c` (Text, 255) - Team member role (e.g., "Account Manager")
     - `Member_Name__c` (Text, 255) - Display name override

2. **Data Migration**: If you have existing Account Team members, you'll need to migrate them to the custom object
   - See "Migrating from Standard Account Team" section below

3. **Custom Field** (if using CMS photos):
   - Create a custom field `ContentKey__c` on the User object
   - Type: Text
   - Purpose: Stores the CMS content key for user profile photos

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

3. **Grant object access**:
   - Go to Setup → Profiles or Permission Sets
   - Grant Read access to `My_Account_Team_Member__c` for your Experience Cloud users
   - Grant access to all fields on the object

### Using VS Code

1. Open the project in VS Code with Salesforce Extensions
2. Right-click on `force-app` folder
3. Select "Deploy Source to Org"
4. Configure permissions as noted above

## Adding to Experience Cloud Site

1. Navigate to **Experience Builder** for your B2B Commerce site
2. Go to the **/my-account** page
3. Drag and drop the **My Account Team** component onto the page
4. Save and publish the site

## Migrating from Standard Account Team

If you have existing data in the standard `AccountTeamMember` object, use this script in Execute Anonymous Apex:

```apex
List<My_Account_Team_Member__c> customTeamMembers = new List<My_Account_Team_Member__c>();

for (AccountTeamMember atm : [
    SELECT AccountId, UserId, User.Email, User.Title, TeamMemberRole
    FROM AccountTeamMember
]) {
    My_Account_Team_Member__c custom = new My_Account_Team_Member__c();
    custom.Account__c = atm.AccountId;
    custom.Team_Member_User__c = atm.UserId;
    custom.Member_Email__c = atm.User.Email;
    custom.Member_Title__c = atm.User.Title;
    custom.Role__c = atm.TeamMemberRole;
    customTeamMembers.add(custom);
}

if (!customTeamMembers.isEmpty()) {
    insert customTeamMembers;
    System.debug('Migrated ' + customTeamMembers.size() + ' team members');
}
```

Or use Data Loader to export from `AccountTeamMember` and import to `My_Account_Team_Member__c`

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