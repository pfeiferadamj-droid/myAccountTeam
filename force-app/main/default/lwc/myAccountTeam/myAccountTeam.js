import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccountTeamMembers from '@salesforce/apex/MyAccountTeamController.getAccountTeamMembers';

export default class MyAccountTeam extends LightningElement {
    teamMembers = [];
    error;
    isLoading = true;

    @wire(getAccountTeamMembers)
    wiredTeamMembers({ error, data }) {
        this.isLoading = false;
        if (data) {
            console.log('Raw data from Apex:', JSON.stringify(data, null, 2));
            this.teamMembers = data.map(member => {
                console.log('Processing member:', member.name);
                console.log('  - Title:', member.title);
                console.log('  - Email:', member.email);
                console.log('  - ContentKey:', member.contentKey);
                return {
                    ...member,
                    mailtoLink: `mailto:${member.email}`,
                    photoUrl: member.contentKey ? this.getCMSImageUrl(member.contentKey) : null
                };
            });
            console.log('Processed teamMembers:', JSON.stringify(this.teamMembers, null, 2));
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'An error occurred while loading team members';
            this.teamMembers = [];
            console.error('Error loading team members:', error);
        }
    }

    getCMSImageUrl(contentKey) {
        // Construct CMS image URL using content key
        // For Salesforce B2B Commerce, try these URL patterns:

        // Option 1: Standard Salesforce Files/Content URL with THUMB rendition
        // return `/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${contentKey}`;

        // Option 2: Original image without rendition specified
        return `/sfc/servlet.shepherd/version/download/${contentKey}`;

        // Option 3: CMS Delivery API (if using managed content)
        // return `/cms/delivery/media/${contentKey}`;

        // Option 4: Direct rendition download
        // return `/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Jpg&versionId=${contentKey}`;
    }

    get hasTeamMembers() {
        return !this.isLoading && !this.error && this.teamMembers.length > 0;
    }

    get showNoTeamMessage() {
        return !this.isLoading && !this.error && this.teamMembers.length === 0;
    }

    get allTeamEmails() {
        return this.teamMembers
            .filter(member => member.email)
            .map(member => member.email)
            .join(',');
    }

    handleContactTeam() {
        const emails = this.allTeamEmails;
        console.log('Contact Team clicked. Emails:', emails);
        console.log('Team members:', this.teamMembers);

        if (!emails) {
            console.warn('No email addresses found');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'No Email Addresses',
                    message: 'No email addresses are available for your team members.',
                    variant: 'warning'
                })
            );
            return;
        }

        // Open default email client with all team members in TO field
        console.log('Opening mailto with:', emails);
        window.location.href = `mailto:${emails}`;
    }
}
