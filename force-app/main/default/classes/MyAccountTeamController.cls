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

            // Deduplicate by user ID, merging isOwner flag
            Map<Id, TeamMember> membersByUserId = new Map<Id, TeamMember>();
            for (My_Account_Team_Member__c atm : accountTeam) {
                Id userId = atm.Team_Member_User__c;
                Boolean isOwner = atm.Is_Owner__c != null ? atm.Is_Owner__c : false;

                if (membersByUserId.containsKey(userId)) {
                    // Merge: preserve isOwner if any record has it
                    if (isOwner) {
                        membersByUserId.get(userId).isOwner = true;
                    }
                } else {
                    TeamMember member = new TeamMember();
                    member.id = userId;
                    member.name = atm.Team_Member_User__r.Name;
                    member.title = atm.Member_Title__c;
                    member.email = atm.Member_Email__c;
                    member.contentKey = atm.Member_ContentKey__c;
                    member.isOwner = isOwner;
                    membersByUserId.put(userId, member);
                }
            }
            teamMembers.addAll(membersByUserId.values());

            // Debug total results
            System.debug('Total team members returned: ' + teamMembers.size());

        } catch (Exception e) {
            System.debug('Error fetching account team: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve account team members: ' + e.getMessage());
        }

        return teamMembers;
    }
}
