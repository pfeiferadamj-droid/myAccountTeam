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
            this.teamMembers = data.map(member => {
                return {
                    ...member,
                    mailtoLink: `mailto:${member.email}`,
                    photoUrl: member.contentKey ? this.getCMSImageUrl(member.contentKey) : null
                };
            });
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'An error occurred while loading team members';
            this.teamMembers = [];
            console.error('Error loading team members:', error);
        }
    }

    getCMSImageUrl(contentKey) {
        // Construct CMS image URL using content key
        // Adjust this based on your CMS configuration
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

        if (!emails) {
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
        window.location.href = `mailto:${emails}`;
    }
}
