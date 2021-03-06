package analytics

import static org.edx.jenkins.dsl.AnalyticsConstants.common_log_rotator
import static org.edx.jenkins.dsl.AnalyticsConstants.common_publishers
import static org.edx.jenkins.dsl.AnalyticsConstants.common_triggers


class ExpireVerticaPassword {

    public static def job = { dslFactory, allVars ->

        dslFactory.job('expire-vertica-password') {
            logRotator common_log_rotator(allVars)
            parameters {
                stringParam('TOOLS_REPO', allVars.get('TOOLS_REPO_URL'), '')
                stringParam('TOOLS_BRANCH', allVars.get('TOOLS_BRANCH', 'origin/master'), 'e.g. tagname or origin/branchname')
                stringParam('CREDENTIALS', allVars.get('CREDENTIALS'))
                stringParam('EXCLUDE', allVars.get('EXCLUDE'))
                stringParam('MAPPING', allVars.get('MAPPING'))
                stringParam('NOTIFY', '$PAGER_NOTIFY', 'Space separated list of emails to send notifications to.')
            }
            multiscm {
                git {
                    remote {
                        url('$TOOLS_REPO')
                        branch('$TOOLS_BRANCH')
                        credentials('1')
                    }
                    extensions {
                        relativeTargetDirectory('analytics-tools')
                        pruneBranches()
                        cleanAfterCheckout()
                    }
                }
            }
            triggers common_triggers(allVars)
            wrappers {
                timestamps()
            }
            publishers common_publishers(allVars)
            publishers {
                extendedEmail {
                    recipientList('$NOTIFY_LIST')
                    defaultSubject('You Vertica password has expired')
                    defaultContent('This is to inform you that you Vertica password has expired. ' +
                    'Please use vsql to set a new password.')
                    triggers {
                        success {
                            sendTo {
                                recipientList()
                            }
                        }
                    }
                }
            }
            steps {
                virtualenv {
                    pythonName('PYTHON_3.7')
                    nature("shell")
                    systemSitePackages(false)
                    command(
                        dslFactory.readFileFromWorkspace("dataeng/resources/expire-vertica-password.sh")
                    )
                }
                environmentVariables {
                    propertiesFile('propsfile')
                }
            }
        }
    }
}
