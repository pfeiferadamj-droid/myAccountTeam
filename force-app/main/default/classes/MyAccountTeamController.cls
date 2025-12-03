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

            // Get all team members from custom object (including owner)
            List<My_Account_Team_Member__c> accountTeam = [
                SELECT Id, Team_Member_User__c, Team_Member_User__r.Name,
                       Member_Email__c, Member_Title__c, Member_ContentKey__c,
                       Role__c, Is_Owner__c
                FROM My_Account_Team_Member__c
                WHERE Account__c = :accountId
                ORDER BY Is_Owner__c DESC, Team_Member_User__r.Name
            ];

            for (My_Account_Team_Member__c atm : accountTeam) {
                TeamMember member = new TeamMember();
                member.id = atm.Team_Member_User__c;
                member.name = atm.Team_Member_User__r.Name;
                member.title = atm.Member_Title__c;
                member.email = atm.Member_Email__c;
                member.contentKey = atm.Member_ContentKey__c;
                member.isOwner = atm.Is_Owner__c != null ? atm.Is_Owner__c : false;

                // Debug logging
                System.debug('Team Member: ' + atm.Team_Member_User__r.Name);
                System.debug('Member Title: ' + atm.Member_Title__c);
                System.debug('Member Email: ' + atm.Member_Email__c);
                System.debug('Member ContentKey: ' + atm.Member_ContentKey__c);
                System.debug('Is Owner: ' + member.isOwner);

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
