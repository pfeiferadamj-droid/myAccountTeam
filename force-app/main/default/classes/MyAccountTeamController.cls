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
            // Get the current user's account
            User currentUser = [
                SELECT AccountId, Account.OwnerId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                AND AccountId != null
                LIMIT 1
            ];

            if (currentUser.AccountId == null) {
                return teamMembers;
            }

            Id accountId = currentUser.AccountId;
            Id ownerId = currentUser.Account.OwnerId;

            // Get Account Owner details
            User accountOwner = [
                SELECT Id, Name, Title, Email, SmallPhotoUrl, ContentKey__c
                FROM User
                WHERE Id = :ownerId
                LIMIT 1
            ];

            TeamMember ownerMember = new TeamMember();
            ownerMember.id = accountOwner.Id;
            ownerMember.name = accountOwner.Name;
            ownerMember.title = accountOwner.Title;
            ownerMember.email = accountOwner.Email;
            ownerMember.contentKey = accountOwner.ContentKey__c;
            ownerMember.isOwner = true;
            teamMembers.add(ownerMember);

            // Get Account Team Members
            List<AccountTeamMember> accountTeam = [
                SELECT Id, UserId, User.Name, User.Title, User.Email, User.ContentKey__c, TeamMemberRole
                FROM AccountTeamMember
                WHERE AccountId = :accountId
                AND UserId != :ownerId
                ORDER BY User.Name
            ];

            for (AccountTeamMember atm : accountTeam) {
                TeamMember member = new TeamMember();
                member.id = atm.UserId;
                member.name = atm.User.Name;
                member.title = atm.User.Title;
                member.email = atm.User.Email;
                member.contentKey = atm.User.ContentKey__c;
                member.isOwner = false;
                teamMembers.add(member);
            }

        } catch (Exception e) {
            System.debug('Error fetching account team: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve account team members: ' + e.getMessage());
        }

        return teamMembers;
    }
}
