/*****************************************************************************************************
* This file is part of the Apex Validation Rules project, released under the MIT License.            *
* See LICENSE file or go to https://github.com/jongpie/ApexValidationRules for full license details. *
*****************************************************************************************************/
public without sharing class ApexValidator {

    private Schema.SObjectType sobjectType;
    private List<SObject> records;

    public ApexValidator() {
        this.sobjectType = Trigger.new != null ? Trigger.new.getSObjectType() : Trigger.old.getSObjectType();
        this.records     = Trigger.new != null ? Trigger.new                  : Trigger.old;
    }

    public ApexValidator(SObject record) {
        this(new List<SObject>{record});
    }

    public ApexValidator(List<SObject> records) {
        this.sobjectType = records[0].getSObjectType();
        this.records     = records;
    }

    public void execute() {
        System.debug('execute');
        for(SObject record : this.records) {
            System.debug('record=' + record);
            for(ApexValidationRule__mdt rule : this.getRules()) {
                System.debug('rule=' + rule);
                List<RuleCriterionValidator> validators = new List<RuleCriterionValidator>();
                for(ApexValidationRuleCriterion__mdt ruleCriterion : rule.ApexValidationRuleCriteria__r) {
                    System.debug('ruleCriterion=' + ruleCriterion);
                    validators.add(new RuleCriterionValidator(ruleCriterion, record));
                    //Boolean isInvalid = new RuleCriterionValidator(ruleCriterion, record).isInvalid();
                    //System.debug('isInvalid=' + isInvalid);
                    //if(isInvalid) record.addError(rule.ErrorMessage__c);
                }
                Boolean isInvalid;
                for(RuleCriterionValidator validator : validators) {
                    isInvalid = validator.isInvalid();
                    if(!isInvalid) break;
                }
                System.debug('isInvalid=' + isInvalid);
            }
        }
    }

    private List<ApexValidationRule__mdt> getRules() {
        System.debug('getRules');
        System.debug('String.valueOf(this.sobjectType)=' + String.valueOf(this.sobjectType));
        return [
            SELECT SObjectType__c, ErrorMessage__c, (
                    SELECT SObjectType__c, Field__c, Field__r.QualifiedApiName, Operator__c, ValueType__c, Value__c
                    FROM ApexValidationRuleCriteria__r
                )
            FROM ApexValidationRule__mdt
            WHERE SObjectType__c = :String.valueOf(this.sobjectType)
            AND IsActive__c = true
        ];
    }

    private class ApexValidatorException extends Exception {}

    private class RuleCriterionValidator {

        private ApexValidationRuleCriterion__mdt ruleCriterion;
        private SObject record;

        private RuleCriterionValidator(ApexValidationRuleCriterion__mdt ruleCriterion, SObject record) {
            this.ruleCriterion = ruleCriterion;
            this.record    = record;
        }

        public Boolean isInvalid() {
            if(this.ruleCriterion.ValueType__c == 'RegEx') return this.isInvalidRegEx();

            String recordFieldValue = this.getFieldValue();
            String comparisonValue  = this.getComparisonValue();

            switch on this.ruleCriterion.Operator__c {
                // TODO kind of critical to, ya know, make sure this works for all data types, etc
                // In theory, should work b/c all SObject Fields have a toString method
                when '==' { return recordFieldValue == comparisonValue; }
                when '!=' { return recordFieldValue != comparisonValue; }
                when '<'  { return recordFieldValue <  comparisonValue; }
                when '<=' { return recordFieldValue <= comparisonValue; }
                when '>'  { return recordFieldValue >  comparisonValue; }
                when '>=' { return recordFieldValue >= comparisonValue; }
                when else { throw new ApexValidatorException('Unknown operator'); }
            }
        }

        private Boolean isInvalidRegEx() {
            Pattern pattern = Pattern.compile(this.ruleCriterion.Value__c);
            return pattern.matcher(this.getFieldValue()).matches();
       }

        private String getFieldValue() {
            return String.valueOf(this.record.get(this.ruleCriterion.Field__r.QualifiedApiName));
        }

        private String getComparisonValue() {
            switch on this.ruleCriterion.ValueType__c {
                when 'Static Value' { return String.escapeSingleQuotes(this.ruleCriterion.Value__c); }
                when 'Field Value'  { return String.valueOf(record.get(this.ruleCriterion.Value__c)); }
                when else           { throw new ApexValidatorException('Unknown Value Type, cannot parse comparison value'); }
            }
        }

    }

}