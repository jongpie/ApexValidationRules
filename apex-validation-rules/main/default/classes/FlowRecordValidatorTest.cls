/********************************************************************************************************
 * This file is part of the Apex Validation Rules project, released under the MIT License.              *
 * See LICENSE file or go to https://github.com/jongpie/RecordValidationRules for full license details. *
 *******************************************************************************************************/

@isTest
private class FlowRecordValidatorTest {
    static RecordValidationRule__mdt createMockRule() {
        return new RecordValidationRule__mdt(
            ConditionLogicType__c = 'AND',
            CustomConditionLogic__c = null,
            DeveloperName = 'Test_rule',
            ErrorMessage__c = 'Whoops, an error occurred',
            IsActive__c = true
        );
    }

    static RecordValidationRuleCondition__mdt createMockRuleCondition(String fieldPath, String operator, String valueType, Object value) {
        String valueString = value instanceof String ? (String) value : JSON.serialize(value);
        return new RecordValidationRuleCondition__mdt(
            FieldPath__c = fieldPath,
            Operator__c = operator,
            SortOrder__c = null,
            Value__c = valueString,
            ValueType__c = valueType
        );
    }

    @isTest
    static void validateForRuleWithStringFieldAndAllOperators() {
        String fieldPath = 'Name';
        String accountName = 'Some account';
        Account record = new Account(Name = 'Test account');
        record.Name = accountName;

        Map<String, String> operatorToValue = new Map<String, String>{
            'EQUAL_TO' => accountName,
            'NOT_EQUAL_TO' => 'something else',
            'CONTAINS' => accountName.left(3)
        };
        for (String operator : operatorToValue.keySet()) {
            String value = operatorToValue.get(operator);

            RecordValidationRule__mdt rule = createMockRule();
            RecordValidationRuleCondition__mdt condition = createMockRuleCondition(fieldPath, operator, 'Value', value);
            List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };
            FlowRecordValidator.setMockRule(rule, conditions);

            FlowRecordValidator.FlowInput input = new FlowRecordValidator.FlowInput();
            input.record = record;
            input.shouldThrowException = false;
            List<FlowRecordValidator.FlowInput> inputs = new List<FlowRecordValidator.FlowInput>{ input };

            List<FlowRecordValidator.FlowOutput> outputs = FlowRecordValidator.validate(inputs);
            System.assertEquals(1, outputs.size(), 'Expected 1 instance of FlowOutput: ' + outputs);
            FlowRecordValidator.FlowOutput output = outputs.get(0);
            System.assertEquals(1, output.results.size(), 'Expected 1 validation rule result: ' + output.results);

            RecordValidator.ValidationRuleResult result = output.results.get(0);
            System.assertEquals(true, result.hasError, result);
            System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

            try {
                input.shouldThrowException = true;
                FlowRecordValidator.validate(inputs);
                System.assert(false, 'Exception expected on line above');
            } catch (RecordValidator.RecordValidatorException ex) {
                System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
            }
        }
    }
}
