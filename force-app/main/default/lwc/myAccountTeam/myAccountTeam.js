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
        // Standard Salesforce ContentVersion download path
        // contentKey should be the ContentVersion ID (e.g., 068...)
        // This path works in Experience Cloud without needing hardcoded channelId/oid
        return `/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=${contentKey}`;
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
        // Using anchor element approach for better compatibility in Experience Cloud
        console.log('Opening mailto with:', emails);
        const mailtoLink = `mailto:${emails}`;
        const anchor = document.createElement('a');
        anchor.href = mailtoLink;
        anchor.target = '_self';
        anchor.click();
    }
}
