// ================================================================
// Monitoring Module: Security and Performance Monitoring
// ================================================================
// Creates Log Analytics workspace, monitoring solutions, and security center integration

// ================================================================
// PARAMETERS
// ================================================================

@description('The Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Naming prefix for resource naming (project-environment-location)')
param namingPrefix string

@description('VMSS resource ID for monitoring')
param vmssResourceId string

// ================================================================
// VARIABLES
// ================================================================

var logAnalyticsWorkspaceName = 'log-${namingPrefix}'
var applicationInsightsName = 'appi-${namingPrefix}'
var actionGroupName = 'ag-${namingPrefix}'

// ================================================================
// LOG ANALYTICS WORKSPACE
// ================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: false
    }
  }
}

// ================================================================
// APPLICATION INSIGHTS
// ================================================================

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// ================================================================
// MONITORING SOLUTIONS
// ================================================================

resource vmInsightsSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'VMInsights(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  plan: {
    name: 'VMInsights(${logAnalyticsWorkspace.name})'
    promotionCode: ''
    product: 'OMSGallery/VMInsights'
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
    containedResources: []
  }
}

resource securitySolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Security(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  plan: {
    name: 'Security(${logAnalyticsWorkspace.name})'
    promotionCode: ''
    product: 'OMSGallery/Security'
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
    containedResources: []
  }
}

resource updatesSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Updates(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  plan: {
    name: 'Updates(${logAnalyticsWorkspace.name})'
    promotionCode: ''
    product: 'OMSGallery/Updates'
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
    containedResources: []
  }
}

// ================================================================
// ACTION GROUP FOR ALERTS
// ================================================================

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: 'VMSSAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'AdminEmail'
        emailAddress: 'admin@example.com'  // Replace with actual email
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: []
    webhookReceivers: []
    azureAppPushReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceivers: []
  }
}

// ================================================================
// METRIC ALERTS
// ================================================================

resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-cpu-${namingPrefix}'
  location: 'Global'
  tags: tags
  properties: {
    description: 'Alert when CPU usage is consistently high'
    severity: 2
    enabled: true
    scopes: [
      vmssResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'Percentage CPU'
          metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource lowMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-mem-${namingPrefix}'
  location: 'Global'
  tags: tags
  properties: {
    description: 'Alert when available memory is low'
    severity: 2
    enabled: true
    scopes: [
      vmssResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'LowMemory'
          metricName: 'Available Memory Bytes'
          metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
          operator: 'LessThan'
          threshold: 1073741824  // 1GB in bytes
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// ================================================================
// SECURITY ALERTS
// ================================================================

resource suspiciousActivityAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-security-${namingPrefix}'
  location: location
  tags: tags
  properties: {
    description: 'Alert on suspicious login activities'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    scopes: [
      logAnalyticsWorkspace.id
    ]
    criteria: {
      allOf: [
        {
          query: 'SecurityEvent | where EventID == 4625 | summarize FailedLogins = count() by Computer | where FailedLogins > 10'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

// ================================================================
// WORKBOOKS
// ================================================================

resource vmssWorkbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid('workbook-vmss-${namingPrefix}')
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: 'VMSS Monitoring Dashboard - ${namingPrefix}'
    serializedData: '{"version":"Notebook/1.0","items":[{"type":1,"content":{"json":"# VMSS Monitoring Dashboard\\n\\nComprehensive monitoring for RHEL 8.10 VMSS with X11 capabilities"},"name":"title"},{"type":3,"content":{"version":"KqlItem/1.0","query":"Perf | where ObjectName == \\"Processor\\" and CounterName == \\"% Processor Time\\" | summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m) | render timechart","size":0,"title":"CPU Usage by Instance","timeContext":{"durationMs":3600000},"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces"},"name":"cpu-chart"}],"styleSettings":{},"$schema":"https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"}'
    category: 'workbook'
    sourceId: logAnalyticsWorkspace.id
  }
}

// ================================================================
// DATA COLLECTION RULES
// ================================================================

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-${namingPrefix}'
  location: location
  tags: tags
  properties: {
    description: 'Data collection for VMSS monitoring'
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounterDataSource10'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\Available Bytes'
            '\\Network Interface(*)\\Bytes Total/sec'
            '\\LogicalDisk(_Total)\\Disk Reads/sec'
            '\\LogicalDisk(_Total)\\Disk Writes/sec'
          ]
        }
      ]
      syslog: [
        {
          name: 'syslogDataSource'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
            'daemon'
            'kern'
            'local0'
            'mail'
            'news'
            'syslog'
            'user'
          ]
          logLevels: [
            'Emergency'
            'Alert'
            'Critical'
            'Error'
            'Warning'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: 'la-destination'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
          'Microsoft-Syslog'
        ]
        destinations: [
          'la-destination'
        ]
      }
    ]
  }
}

// ================================================================
// OUTPUTS
// ================================================================

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output applicationInsightsId string = applicationInsights.id
output actionGroupId string = actionGroup.id
output workbookId string = vmssWorkbook.id

// Monitoring Configuration Summary
output monitoringSummary object = {
  logAnalyticsWorkspace: logAnalyticsWorkspace.name
  applicationInsights: applicationInsights.name
  alertsConfigured: [
    'High CPU Usage (>80%)'
    'Low Memory (<1GB)'
    'Suspicious Login Activities'
  ]
  solutionsInstalled: [
    'VM Insights'
    'Security Center'
    'Update Management'
  ]
  dataRetention: '90 days'
  workbooksCreated: [
    'VMSS Monitoring Dashboard'
  ]
}