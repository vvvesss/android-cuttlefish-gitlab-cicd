# scripts/test-reporter.py
import json
import sys
import os
import xml.etree.ElementTree as ET
from datetime import datetime
import requests
from typing import Dict, List, Any

class TestReporter:
    def __init__(self):
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'pipeline_id': os.environ.get('CI_PIPELINE_ID'),
            'commit_sha': os.environ.get('CI_COMMIT_SHA'),
            'branch': os.environ.get('CI_COMMIT_REF_NAME'),
            'tests': {
                'unit_tests': {},
                'integration_tests': {},
                'performance_tests': {},
                'security_tests': {}
            },
            'summary': {
                'total_tests': 0,
                'passed': 0,
                'failed': 0,
                'skipped': 0,
                'duration': 0
            }
        }
    
    def parse_junit_xml(self, xml_file: str) -> Dict[str, Any]:
        """Parse JUnit XML test results"""
        try:
            tree = ET.parse(xml_file)
            root = tree.getroot()
            
            test_results = {
                'test_count': int(root.get('tests', 0)),
                'failures': int(root.get('failures', 0)),
                'errors': int(root.get('errors', 0)),
                'skipped': int(root.get('skipped', 0)),
                'time': float(root.get('time', 0)),
                'test_cases': []
            }
            
            for testcase in root.findall('.//testcase'):
                case = {
                    'name': testcase.get('name'),
                    'classname': testcase.get('classname'),
                    'time': float(testcase.get('time', 0)),
                    'status': 'passed'
                }
                
                if testcase.find('failure') is not None:
                    case['status'] = 'failed'
                    case['failure'] = testcase.find('failure').text
                elif testcase.find('error') is not None:
                    case['status'] = 'error'
                    case['error'] = testcase.find('error').text
                elif testcase.find('skipped') is not None:
                    case['status'] = 'skipped'
                
                test_results['test_cases'].append(case)
            
            return test_results
            
        except Exception as e:
            print(f"Error parsing XML: {e}")
            return {}
    
    def parse_cuttlefish_results(self, results_file: str) -> Dict[str, Any]:
        """Parse Cuttlefish test orchestrator results"""
        try:
            with open(results_file, 'r') as f:
                content = f.read()
            
            # Parse instrumentation test results
            test_results = {
                'total_tests': 0,
                'passed': 0,
                'failed': 0,
                'test_cases': []
            }
            
            # Simple parsing - in real scenario, you'd parse the actual format
            lines = content.split('\n')
            for line in lines:
                if 'Test results for' in line:
                    test_results['total_tests'] += 1
                    if 'OK' in line:
                        test_results['passed'] += 1
                    elif 'FAILURES' in line:
                        test_results['failed'] += 1
            
            return test_results
            
        except Exception as e:
            print(f"Error parsing Cuttlefish results: {e}")
            return {}
    
    def parse_performance_results(self, perf_file: str) -> Dict[str, Any]:
        """Parse performance test results"""
        try:
            with open(perf_file, 'r') as f:
                content = f.read()
            
            # Extract performance metrics
            performance_data = {
                'startup_times': [],
                'memory_usage': {},
                'cpu_usage': {}
            }
            
            # Simple parsing - extract startup times
            lines = content.split('\n')
            for line in lines:
                if 'TotalTime:' in line:
                    time_ms = int(line.split(':')[1].strip())
                    performance_data['startup_times'].append(time_ms)
            
            if performance_data['startup_times']:
                performance_data['avg_startup_time'] = sum(performance_data['startup_times']) / len(performance_data['startup_times'])
                performance_data['max_startup_time'] = max(performance_data['startup_times'])
                performance_data['min_startup_time'] = min(performance_data['startup_times'])
            
            return performance_data
            
        except Exception as e:
            print(f"Error parsing performance results: {e}")
            return {}
    
    def generate_dashboard_metrics(self) -> Dict[str, Any]:
        """Generate metrics for Grafana dashboard"""
        metrics = {
            'pipeline_success_rate': 0,
            'test_coverage': 0,
            'performance_regression': False,
            'security_score': 0,
            'build_duration': 0
        }
        
        # Calculate success rate
        total_tests = self.results['summary']['total_tests']
        if total_tests > 0:
            metrics['pipeline_success_rate'] = (self.results['summary']['passed'] / total_tests) * 100
        
        # Export metrics to file for Grafana
        with open('pipeline_metrics.json', 'w') as f:
            json.dump(metrics, f, indent=2)
        
        return metrics
    
    def send_to_slack(self, webhook_url: str = None):
        """Send results to Slack"""
        webhook_url = webhook_url or os.environ.get('SLACK_WEBHOOK_URL')
        if not webhook_url:
            print("No Slack webhook URL provided")
            return
        
        # Create Slack message
        summary = self.results['summary']
        color = "good" if summary['failed'] == 0 else "danger"
        
        message = {
            "attachments": [
                {
                    "color": color,
                    "title": f"🚀 Pipeline Results - {self.results['branch']}",
                    "fields": [
                        {
                            "title": "Tests",
                            "value": f"✅ {summary['passed']} passed\n❌ {summary['failed']} failed\n⏭️ {summary['skipped']} skipped",
                            "short": True
                        },
                        {
                            "title": "Pipeline",
                            "value": f"📊 Pipeline ID: {self.results['pipeline_id']}\n🔗 Commit: {self.results['commit_sha'][:8]}",
                            "short": True
                        }
                    ],
                    "footer": "Android DevOps Pipeline",
                    "ts": int(datetime.now().timestamp())
                }
            ]
        }
        
        try:
            response = requests.post(webhook_url, json=message)
            if response.status_code == 200:
                print("✅ Slack notification sent successfully")
            else:
                print(f"❌ Failed to send Slack notification: {response.status_code}")
        except Exception as e:
            print(f"❌ Error sending Slack notification: {e}")
    
    def generate_html_report(self):
        """Generate HTML report"""
        html_template = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Android DevOps Pipeline Report</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .header { background: #2196F3; color: white; padding: 20px; border-radius: 5px; }
                .summary { display: flex; gap: 20px; margin: 20px 0; }
                .metric { background: #f5f5f5; padding: 15px; border-radius: 5px; flex: 1; }
                .passed { border-left: 5px solid #4CAF50; }
                .failed { border-left: 5px solid #f44336; }
                .test-details { margin: 20px 0; }
                table { width: 100%; border-collapse: collapse; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>🚀 Android DevOps Pipeline Report</h1>
                <p>Pipeline ID: {pipeline_id} | Branch: {branch} | Commit: {commit_sha}</p>
                <p>Generated: {timestamp}</p>
            </div>
            
            <div class="summary">
                <div class="metric passed">
                    <h3>✅ Passed Tests</h3>
                    <h2>{passed}</h2>
                </div>
                <div class="metric failed">
                    <h3>❌ Failed Tests</h3>
                    <h2>{failed}</h2>
                </div>
                <div class="metric">
                    <h3>⏱️ Duration</h3>
                    <h2>{duration}s</h2>
                </div>
                <div class="metric">
                    <h3>📊 Success Rate</h3>
                    <h2>{success_rate}%</h2>
                </div>
            </div>
            
            <div class="test-details">
                <h2>📱 Test Results Details</h2>
                <!-- Test details would be inserted here -->
            </div>
        </body>
        </html>
        """
        
        summary = self.results['summary']
        success_rate = (summary['passed'] / summary['total_tests'] * 100) if summary['total_tests'] > 0 else 0
        
        html_content = html_template.format(
            pipeline_id=self.results['pipeline_id'],
            branch=self.results['branch'],
            commit_sha=self.results['commit_sha'][:8],
            timestamp=self.results['timestamp'],
            passed=summary['passed'],
            failed=summary['failed'],
            duration=summary['duration'],
            success_rate=f"{success_rate:.1f}"
        )
        
        with open('final-pipeline-report.html', 'w') as f:
            f.write(html_content)
        
        print("📊 HTML report generated: final-pipeline-report.html")

def main():
    reporter = TestReporter()
    
    if len(sys.argv) < 2:
        print("Usage: python3 test-reporter.py <test_results_file> [--generate-final-report] [--send-to-slack]")
        sys.exit(1)
    
    # Parse command line arguments
    if "--generate-final-report" in sys.argv:
        # Generate final comprehensive report
        reporter.generate_html_report()
        reporter.generate_dashboard_metrics()
        
        # Save final JSON report
        with open('final-pipeline-report.json', 'w') as f:
            json.dump(reporter.results, f, indent=2)
        
        print("📊 Final pipeline report generated")
        return
    
    if "--send-to-slack" in sys.argv:
        # Load existing results and send to Slack
        try:
            with open('final-pipeline-report.json', 'r') as f:
                reporter.results = json.load(f)
            reporter.send_to_slack()
        except FileNotFoundError:
            print("❌ No final report found to send to Slack")
        return
    
    # Parse individual test results
    test_file = sys.argv[1]
    
    if test_file.endswith('.xml'):
        # JUnit XML format
        junit_results = reporter.parse_junit_xml(test_file)
        reporter.results['tests']['unit_tests'] = junit_results
        reporter.results['summary']['total_tests'] += junit_results.get('test_count', 0)
        reporter.results['summary']['passed'] += junit_results.get('test_count', 0) - junit_results.get('failures', 0) - junit_results.get('errors', 0)
        reporter.results['summary']['failed'] += junit_results.get('failures', 0) + junit_results.get('errors', 0)
        
    elif 'performance' in test_file:
        # Performance results
        perf_results = reporter.parse_performance_results(test_file)
        reporter.results['tests']['performance_tests'] = perf_results
        
    else:
        # Cuttlefish integration test results
        integration_results = reporter.parse_cuttlefish_results(test_file)
        reporter.results['tests']['integration_tests'] = integration_results
        reporter.results['summary']['total_tests'] += integration_results.get('total_tests', 0)
        reporter.results['summary']['passed'] += integration_results.get('passed', 0)
        reporter.results['summary']['failed'] += integration_results.get('failed', 0)
    
    # Save individual test report
    output_file = f"{test_file.split('.')[0]}-report.json"
    with open(output_file, 'w') as f:
        json.dump(reporter.results, f, indent=2)
    
    print(f"📊 Test report saved: {output_file}")

if __name__ == "__main__":
    main()
