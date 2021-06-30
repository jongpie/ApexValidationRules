/********************************************************************************************************
 * This file is part of the Apex Validation Rules project, released under the MIT License.              *
 * See LICENSE file or go to https://github.com/jongpie/RecordValidationRules for full license details. *
 *******************************************************************************************************/

public without sharing class FlowRecordValidator {
    private static final Map<RecordValidationRule__mdt, List<RecordValidationRuleCondition__mdt>> MOCK_RULE_TO_CONDITIONS = new Map<RecordValidationRule__mdt, List<RecordValidationRuleCondition__mdt>>();

    @testVisible
    private static void setMockRule(RecordValidationRule__mdt rule, List<RecordValidationRuleCondition__mdt> conditions) {
        MOCK_RULE_TO_CONDITIONS.put(rule, conditions);
    }

    public class FlowInput {
        @InvocableVariable(required=true label='Record')
        public SObject record;

        @InvocableVariable(label='Throw Error')
        public Boolean shouldThrowException;
    }

    public class FlowOutput {
        @InvocableVariable
        public List<RecordValidator.ValidationRuleResult> results;
    }

    @InvocableMethod
    public static List<FlowOutput> validate(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        for (FlowInput input : inputs) {
            FlowOutput output = new FlowOutput();
            RecordValidator validator = new RecordValidator(input.record);

            if (MOCK_RULE_TO_CONDITIONS.isEmpty() == false) {
                for (RecordValidationRule__mdt rule : MOCK_RULE_TO_CONDITIONS.keySet()) {
                    List<RecordValidationRuleCondition__mdt> conditions = MOCK_RULE_TO_CONDITIONS.get(rule);

                    validator.setRule(rule, conditions);
                }
            }

            output.results = validator.validate(input.shouldThrowException);
            outputs.add(output);
        }
        return outputs;
    }
}
