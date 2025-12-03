public with sharing class MyAccountTeamController {

    public class TeamMember {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String email;
        @AuraEnabled public String contentKey;
        @AuraEnabled public Boolean isOwner;
    }

    @AuraEnabled(cacheable=true)
    public static List<TeamMember> getAccountTeamMembers() {
        List<TeamMember> teamMembers = new List<TeamMember>();

        try {
            // Get the current user's contact and account (for B2B Commerce users)
            User currentUser = [
                SELECT Id, ContactId, Contact.AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            // Check if user has a contact with an account (B2B Commerce scenario)
            if (currentUser.ContactId == null || currentUser.Contact.AccountId == null) {
                return teamMembers;
            }

            Id accountId = currentUser.Contact.AccountId;

            // Get Account Owner
            Account userAccount = [
                SELECT OwnerId
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            Id ownerId = userAccount.OwnerId;

            // Get Account Owner details (query as list to avoid exception)
            List<User> accountOwners = [
                SELECT Id, Name, Title, Email, SmallPhotoUrl
                FROM User
                WHERE Id = :ownerId
                LIMIT 1
            ];

            // Add Account Owner if it's a User
            if (!accountOwners.isEmpty()) {
                User accountOwner = accountOwners[0];
                TeamMember ownerMember = new TeamMember();
                ownerMember.id = accountOwner.Id;
                ownerMember.name = accountOwner.Name;
                ownerMember.title = accountOwner.Title;
                ownerMember.email = accountOwner.Email;
                ownerMember.contentKey = null; // Will be set separately if field exists
                ownerMember.isOwner = true;

                // Debug logging
                System.debug('Account Owner: ' + accountOwner.Name);
                System.debug('Owner Title: ' + accountOwner.Title);
                System.debug('Owner Email: ' + accountOwner.Email);

                teamMembers.add(ownerMember);
            }

            // Get Account Team Members from custom object (accessible in Experience Cloud)
            List<My_Account_Team_Member__c> accountTeam = [
                SELECT Id, Team_Member_User__c, Team_Member_User__r.Name,
                       Team_Member_User__r.Title, Team_Member_User__r.Email, Role__c
                FROM My_Account_Team_Member__c
                WHERE Account__c = :accountId
                AND Team_Member_User__c != :ownerId
                ORDER BY Team_Member_User__r.Name
            ];
            for (My_Account_Team_Member__c atm : accountTeam) {
                TeamMember member = new TeamMember();
                member.id = atm.Team_Member_User__c;
                member.name = atm.Team_Member_User__r.Name;
                member.title = atm.Team_Member_User__r.Title;
                member.email = atm.Team_Member_User__r.Email;
                member.contentKey = null; // CMS integration - set if field exists
                member.isOwner = false;

                // Debug logging
                System.debug('Team Member: ' + atm.Team_Member_User__r.Name);
                System.debug('Member Title: ' + atm.Team_Member_User__r.Title);
                System.debug('Member Email: ' + atm.Team_Member_User__r.Email);

                teamMembers.add(member);
            }

            // Debug total results
            System.debug('Total team members returned: ' + teamMembers.size());

        } catch (Exception e) {
            System.debug('Error fetching account team: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve account team members: ' + e.getMessage());
        }

        return teamMembers;
    }
}
