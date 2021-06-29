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
    static void validateForRuleWithOneBooleanFieldCondition() {
        Boolean userIsActive = false;
        User user = new User(IsActive = userIsActive);

        RecordValidationRule__mdt rule = createMockRule('user_test', Schema.User.SObjectType);
        RecordValidationRuleCondition__mdt condition = createMockRuleCondition('isactive_condition', 'IsActive', '==', 'Value', String.valueOf(userIsActive));
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

        RecordValidator validator = new RecordValidator(user).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch(RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithOneCurrencyFieldCondition() {
        Integer accountAnnualRevenue = 123000;
        Account account = createMockAccount();
        account.AnnualRevenue = accountAnnualRevenue;

        RecordValidationRule__mdt rule = createMockRule('account_test', Schema.Account.SObjectType);
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{
            createMockRuleCondition('revenue_condition', 'AnnualRevenue', '>=', 'Value', String.valueOf(accountAnnualRevenue))
        };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch(RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithOneDateFieldCondition() {
        Date opportunityCloseDate = System.today();
        Opportunity opportunity = new Opportunity(CloseDate = opportunityCloseDate);

        RecordValidationRule__mdt rule = createMockRule('opportunity_test', Schema.Opportunity.SObjectType);
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{
            createMockRuleCondition('close_date_condition', 'CloseDate', '==', 'Value', JSON.serialize(opportunityCloseDate))
        };

        RecordValidator validator = new RecordValidator(opportunity).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);
    }

    @isTest
    static void validateForRuleWithOneDatetimeFieldCondition() {
        Datetime eventActivityDatetime = System.now().addDays(-3);
        Event event = new Event(ActivityDatetime = eventActivityDatetime);

        RecordValidationRule__mdt rule = createMockRule('event_test', Schema.Event.SObjectType);
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{
            createMockRuleCondition('acitivity_datetime_condition', 'ActivityDatetime', '<=', 'Value', JSON.serialize(eventActivityDatetime))
        };

        RecordValidator validator = new RecordValidator(event).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);
    }

    @isTest
    static void validateForRuleWithOneIntegerFieldCondition() {
        Integer accountNumberOfEmployees = 10;
        Account account = createMockAccount();
        account.NumberOfEmployees = accountNumberOfEmployees;

        RecordValidationRule__mdt rule = createMockRule('account_test', Schema.Account.SObjectType);
        RecordValidationRuleCondition__mdt condition = createMockRuleCondition('number_of_employees_condition', 'NumberOfEmployees', '==', 'Value', String.valueOf(accountNumberOfEmployees));
                List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch(RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithOneRegexFieldCondition() {
        String accountName = '123';
        Account account = createMockAccount();
        account.Name = accountName;

        RecordValidationRule__mdt rule = createMockRule('account_test', Schema.Account.SObjectType);
        RecordValidationRuleCondition__mdt condition = createMockRuleCondition('regex_condition', 'Name', '^[0-9]+$', 'RegEx', accountName);
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch(RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithOneStringFieldCondition() {
        String accountName = 'Some account';
        Account account = createMockAccount();
        account.Name = accountName;

        RecordValidationRule__mdt rule = createMockRule('account_test', Schema.Account.SObjectType);
        RecordValidationRuleCondition__mdt condition = createMockRuleCondition('name_condition', 'Name', '==', 'Value', accountName);
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch(RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithAndConditions() {
        String accountName = 'Some account';
        Integer accountAnnualRevenue = 123000;
        Account account = createMockAccount();
        account.Name = accountName;
        account.AnnualRevenue = accountAnnualRevenue;

        RecordValidationRule__mdt rule = createMockRule('account_test', Schema.Account.SObjectType);
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{
            createMockRuleCondition('name_condition', 'Name', '==', 'Value', accountName),
            createMockRuleCondition('revenue_condition', 'AnnualRevenue', '>=', 'Value', String.valueOf(accountAnnualRevenue))
        };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch(RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithOrConditions() {
        String accountName1 = 'Some account';
        String accountName2 = 'another account';
        Account account = createMockAccount();
        account.Name = accountName1;

        RecordValidationRule__mdt rule = createMockRule('account_test', Schema.Account.SObjectType);
        rule.ConditionLogicType__c = 'OR';
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{
            createMockRuleCondition('name_condition', 'Name', '==', 'Value', accountName1),
            createMockRuleCondition('revenue_condition', 'Name', '==', 'Value', accountName2)
        };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch(RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithCustomConditions() {
        String accountName1 = 'Some account';
        String accountName2 = 'another account';
        Integer accountAnnualRevenue = 123000;
        Account account = createMockAccount();
        account.Name = accountName1;
        account.AnnualRevenue = accountAnnualRevenue;

        RecordValidationRule__mdt rule = createMockRule('account_test', Schema.Account.SObjectType);
        rule.ConditionLogicType__c = 'Custom';
        rule.CustomConditionLogic__c = '((1 OR 2) AND 3)';
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{
            createMockRuleCondition('name_1_condition', 'Name', '==', 'Value', accountName1),
            createMockRuleCondition('name_2_condition', 'Name', '==', 'Value', accountName2),
            createMockRuleCondition('revenue_condition', 'AnnualRevenue', '>=', 'Value', String.valueOf(accountAnnualRevenue))
        };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.getResults();
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);


        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch(RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }
}
