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

    public void validate() {
        System.debug('validate');
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

    private class RuleCriterionValidator {

        private ApexValidationRuleCriterion__mdt ruleCriterion;
        private SObject record;

        private RuleCriterionValidator(ApexValidationRuleCriterion__mdt ruleCriterion, SObject record) {
            this.ruleCriterion = ruleCriterion;
            this.record    = record;
        }

        public Boolean isInvalid() {
            if(this.ruleCriterion.ValueType__c == 'RegEx') return this.isInvalidRegEx();

            Object recordFieldValue = this.getFieldValue();
            Object comparisonValue  = this.getComparisonValue();

            switch on this.ruleCriterion.Operator__c {
                // TODO kind of critical to, ya know, make sure this works for all data types, etc
                // In theory, should work b/c all SObject Fields have a toString method
                when '==' { return String.valueOf(recordFieldValue)    ==   String.valueOf(comparisonValue); }
                when '!=' { return String.valueOf(recordFieldValue)    !=   String.valueOf(comparisonValue); }
                when '<'  { return String.valueOf(recordFieldValue)    <    String.valueOf(comparisonValue); }
                when '>'  { return String.valueOf(recordFieldValue)    >    String.valueOf(comparisonValue); }
                when '<=' { return String.valueOf(recordFieldValue)    <=   String.valueOf(comparisonValue); }
                when '>=' { return String.valueOf(recordFieldValue)    >=   String.valueOf(comparisonValue); }
                when else { return true; }
            }
        }

        private Boolean isInvalidRegEx() {
            Pattern pattern = Pattern.compile(this.ruleCriterion.Value__c);
            Matcher matcher = pattern.matcher(String.valueOf(this.getFieldValue()));
            return matcher.matches();
        }

        private Object getFieldValue() {
            return this.record.get(this.ruleCriterion.Field__r.QualifiedApiName);
        }

        private Object getComparisonValue() {
            if(this.ruleCriterion.Value__c == null) return null;
            else if(this.ruleCriterion.ValueType__c == 'Static Value') return this.ruleCriterion.Value__c;
            else if(this.ruleCriterion.ValueType__c == 'Field Value') return record.get(this.ruleCriterion.Value__c);
            else return null;
        }

    }

}