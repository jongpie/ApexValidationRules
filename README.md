# Apex Validation Rules for Salesforce
[![Travis CI](https://img.shields.io/travis/jongpie/ApexValidationRules/master.svg)](https://travis-ci.org/jongpie/ApexValidationRules)

<a href="https://githubsfdeploy.herokuapp.com" target="_blank">
    <img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

An Apex library for making code-based validations configurable via custom metadata types
1. Create validation rules via ApexValidationRule__mdt custom metadata type
2. Call ApexValidator class in your trigger handler or class to validate the your records pass your validation rules