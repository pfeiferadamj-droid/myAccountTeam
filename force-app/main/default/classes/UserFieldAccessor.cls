public without sharing class UserFieldAccessor {

    public static List<User> getUserDetails(Set<Id> userIds) {
        return [
            SELECT Id, Name, Title, Email
            FROM User
            WHERE Id IN :userIds
        ];
    }
}
