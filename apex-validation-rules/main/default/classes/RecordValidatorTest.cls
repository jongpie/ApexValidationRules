/*****************************************************************************************************
 * This file is part of the Apex Validation Rules project, released under the MIT License.            *
 * See LICENSE file or go to https://github.com/jongpie/ApexValidationRules for full license details. *
 *****************************************************************************************************/
@isTest
private class RecordValidatorTest {
    static RecordValidationRule__mdt createMockRule(String developerName, SObjectType sobjectType) {
        return new RecordValidationRule__mdt(
            ConditionLogicType__c = 'AND',
            CustomConditionLogic__c = null,
            DeveloperName = developerName,
            ErrorMessage__c = 'Whoops, an error occurred',
            IsActive__c = true,
            SObjectType__c = sobjectType.getDescribe().getName()
        );
    }

    static RecordValidationRuleCondition__mdt createMockRuleCondition(String developerName, String fieldPath, String operator, String valueType, String value) {
        return new RecordValidationRuleCondition__mdt(
            DeveloperName = developerName,
            FieldPath__c = fieldPath,
            Operator__c = operator,
            SortOrder__c = null,
            Value__c = value,
            ValueType__c = valueType
        );
    }

    static Account createMockAccount() {
        return new Account(
            Name = 'Test account'
        );
    }

    @isTest
    static void returnValidationResultsForASingleRecord() {
        String accountName = 'Some account';
        Account account = createMockAccount();
        account.Name = accountName;

        RecordValidationRule__mdt rule = createMockRule('account_test', Schema.Account.SObjectType);
        RecordValidationRuleCondition__mdt condition = createMockRuleCondition('some_condition', 'Name', '==', 'Value', accountName);
System.debug('condition==' + condition);

        RecordValidator validator = new RecordValidator(account).setRule(rule, new List<RecordValidationRuleCondition__mdt>{ condition });
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
    }
}
