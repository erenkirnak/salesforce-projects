/******************************************************
 * @Name             : ContactTriggerHandler.cls
 * @Description      : Handles Contact Trigger
 * @Created By       : Eren Kırnak
 * @Created Date     : Oct 13, 2022
 * @Modification Log :
 *******************************************************/
public with sharing class ContactTriggerHandler {
    /******************************************************
     * @Name             : handleBefore
     * @Description      : Validates contact info before insert/update
     * @Created By       : Eren Kırnak
     * @Created Date     : Oct 13, 2022
     * @Param List<Contact> Contacts to be validate
     *******************************************************/
    public static void handleBefore(List<Contact> contacts) {
        List<Id> accountIds = new List<Id>();
        for (Contact contact : contacts) {
            accountIds.add(contact.AccountId);
        }

        Map<Id, Contact> primContactMap = new Map<Id, Contact>();
        List<Contact> primContacts;
        try {
            primContacts = [
                SELECT Id, AccountId
                FROM Contact
                WHERE AccountId IN :accountIds AND Is_Primary_Contact__c = TRUE
            ];
        } catch (QueryException e) {
            throw new HandledException(e.getMessage());
        }
        for (Contact primContact : primContacts) {
            primContactMap.put(primContact.AccountId, primContact);
        }

        // Validate
        for (Contact contact : contacts) {
            Contact oldPrimaryContact = primContactMap.get(contact.AccountId);
            if (
                !contact.Is_Primary_Contact__c &&
                oldPrimaryContact != null &&
                oldPrimaryContact.Id != contact.Id &&
                primContacts.size() > 1
            ) {
                contact.addError(
                    'There is a primary contact associated with the account already.'
                );
            }
        }
    }
    /******************************************************
     * @Name             : handleAfterInsert
     * @Description      : Updates primary contact phone after insert
     * @Created By       : Eren Kırnak
     * @Created Date     : Oct 13, 2022
     * @Param List<Contact> inserted Contacts
     *******************************************************/

    public static void handleAfterInsert(List<Contact> inserted) {
        handleAfterHelper(inserted, null, true);
    }
    /******************************************************
     * @Name             : handleAfterUpdate
     * @Description      : Updates primary contact phone after update
     * @Created By       : Eren Kırnak
     * @Created Date     : Oct 13, 2022
     * @Param List<Contact> updated Contacts
     * @Param Map<Id, Contact> oldMap Contacts
     *******************************************************/

    public static void handleAfterUpdate(
        List<Contact> updated,
        Map<Id, Contact> oldMap
    ) {
        handleAfterHelper(updated, oldMap, false);
    }

    /******************************************************
     * @Name             : handleAfterHelper
     * @Description      : Updates primary contact phone after insert insert/update
     * @Created By       : Eren Kırnak
     * @Created Date     : Oct 13, 2022
     * @Param List<Contact> Contacts
     * @Param Map<Id, Contact> oldMap Contacts
     * @Param Map<Id, Contact> Contacts
     * @Param Boolen checking if contact is inserted
     *******************************************************/
    private static void handleAfterHelper(
        List<Contact> contacts,
        Map<Id, Contact> oldMap,
        Boolean isInsert
    ) {
        Map<Id, String> accountIdPhoneMap = new Map<Id, String>();
        for (Contact newPrimaryContact : contacts) {
            // If new primary contact is inserted or either the Is_Primary_Contact__c or the Phone field is updated.
            if (
                newPrimaryContact.Is_Primary_Contact__c &&
                (isInsert ||
                (oldMap.get(newPrimaryContact.Id).Is_Primary_Contact__c !=
                newPrimaryContact.Is_Primary_Contact__c ||
                oldMap.get(newPrimaryContact.Id).Phone !=
                newPrimaryContact.Phone))
            ) {
                accountIdPhoneMap.put(
                    newPrimaryContact.AccountId,
                    newPrimaryContact.Phone
                );
            }
        }

        if (accountIdPhoneMap.size() != 0) {
            ContactPrimaryPhoneAsyncUpdater.updatePrimaryPhoneOfAccount(
                accountIdPhoneMap
            );
        }
    }
}
