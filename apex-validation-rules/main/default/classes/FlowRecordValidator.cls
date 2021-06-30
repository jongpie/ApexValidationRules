/********************************************************************************************************
 * This file is part of the Apex Validation Rules project, released under the MIT License.              *
 * See LICENSE file or go to https://github.com/jongpie/RecordValidationRules for full license details. *
 *******************************************************************************************************/

public without sharing class FlowRecordValidator {
    private static final Map<String, RecordValidationRule__mdt> MOCK_RULES_BY_DEVELOPER_NAME = new Map<String, RecordValidationRule__mdt>();
    private static final Map<String, List<RecordValidationRuleCondition__mdt>> MOCK_CONDITIONS_BY_RULE_DEVELOPER_NAME = new Map<String, List<RecordValidationRuleCondition__mdt>>();
    private static final Map<String, List<RecordValidationRuleTranslation__mdt>> MOCK_TRAMSLATTIONS_BY_RULE_DEVELOPER_NAME = new Map<String, List<RecordValidationRuleTranslation__mdt>>();

    public class FlowInput {
        @InvocableVariable(required=true label='Record')
        public SObject record;

        @InvocableVariable(required = true label='Throw Error')
        public Boolean shouldThrowException = true;
    }

    public class FlowOutput {
        @InvocableVariable
        public List<RecordValidator.ValidationRuleResult> results;
    }

    @InvocableMethod(
        category='Record Validation'
        label='Validate SObject Record'
        description='Validates a record, using rules & conditions defined in RecordValidationRule__mdt'
    )
    public static List<FlowOutput> validate(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        for (FlowInput input : inputs) {
            FlowOutput output = new FlowOutput();
            RecordValidator validator = new RecordValidator(input.record);

            if (MOCK_RULES_BY_DEVELOPER_NAME.isEmpty() == false) {
                for (String ruleDeveloperName : MOCK_RULES_BY_DEVELOPER_NAME.keySet()) {
                    RecordValidationRule__mdt rule = MOCK_RULES_BY_DEVELOPER_NAME.get(ruleDeveloperName);
                    List<RecordValidationRuleCondition__mdt> conditions = MOCK_CONDITIONS_BY_RULE_DEVELOPER_NAME.get(ruleDeveloperName);

                    validator.setRule(rule, conditions);
                }
            }

            output.results = validator.validate(input.shouldThrowException);
            outputs.add(output);
        }
        return outputs;
    }

    // Private testVisible methods for setting mock CMDT records
    @testVisible
    private static void setMockRule(
        RecordValidationRule__mdt rule,
        List<RecordValidationRuleCondition__mdt> conditions
    ) {
        setMockRule(rule, conditions, null);
    }

    @testVisible
    private static void setMockRule(
        RecordValidationRule__mdt rule,
        List<RecordValidationRuleCondition__mdt> conditions,
        List<RecordValidationRuleTranslation__mdt> translations
    ) {
        MOCK_RULES_BY_DEVELOPER_NAME.put(rule.DeveloperName, rule);
        MOCK_CONDITIONS_BY_RULE_DEVELOPER_NAME.put(rule.DeveloperName, conditions);
        MOCK_TRAMSLATTIONS_BY_RULE_DEVELOPER_NAME.put(rule.DeveloperName, translations);
    }
}
