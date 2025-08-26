"use client"
	import { useState, useEffect, useRef } from "react"
	import { useToast } from "@/components/ui/use-toast"
	import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from "recharts"
	// 测试用例接口
	interface TestCase {
	  id: string
	  name: string
	  type: "unit" | "integration" | "e2e" | "performance" | "accessibility"
	  status: "pending" | "running" | "passed" | "failed" | "skipped"
	  duration: number
	  code: string
	  description: string
	  assertions: number
	  coverage: number
	  error?: string
	  fixSuggestion?: string
	}
	// 测试套件接口
	interface TestSuite {
	  id: string
	  name: string
	  tests: TestCase[]
	  totalTests: number
	  passedTests: number
	  failedTests: number
	  coverage: number
	  duration: number
	  createdAt: Date
	  componentCode: string
	  config: TestGenerationConfig
	}
	// 测试配置接口
	interface TestGenerationConfig {
	  framework: "jest" | "vitest" | "cypress" | "playwright" | "mocha" | "jasmine"
	  testTypes: string[]
	  coverage: boolean
	  mocking: boolean
	  accessibility: boolean
	  performance: boolean
	  visualRegression: boolean
	}
	// 测试历史记录接口
	interface TestHistory {
	  id: string
	  suiteId: string
	  timestamp: Date
	  results: {
	    passed: number
	    failed: number
	    coverage: number
	    duration: number
	  }
	}
	// CI/CD配置接口
	interface CICDConfig {
	  type: "github" | "gitlab" | "jenkins" | "azure"
	  ymlContent: string
	}
	export function AutomatedTestGenerator() {
	  const { toast } = useToast()
	  const [isGenerating, setIsGenerating] = useState(false)
	  const [isRunning, setIsRunning] = useState(false)
	  const [generationProgress, setGenerationProgress] = useState(0)
	  const [runProgress, setRunProgress] = useState(0)
	  const [config, setConfig] = useState<TestGenerationConfig>({
	    framework: "jest",
	    testTypes: ["unit", "integration"],
	    coverage: true,
	    mocking: true,
	    accessibility: false,
	    performance: false,
	    visualRegression: false,
	  })
	  const [testSuites, setTestSuites] = useState<TestSuite[]>([])
	  const [selectedSuite, setSelectedSuite] = useState<string | null>(null)
	  const [componentCode, setComponentCode] = useState("")
	  const [testHistory, setTestHistory] = useState<TestHistory[]>([])
	  const [ciConfig, setCiConfig] = useState<CICDConfig | null>(null)
	  const [showHistory, setShowHistory] = useState(false)
	  const [showCiConfig, setShowCiConfig] = useState(false)
	  const [compareMode, setCompareMode] = useState(false)
	  const [compareSuites, setCompareSuites] = useState<[string | null, string | null]>([null, null])
	  const testWorkerRef = useRef<Worker | null>(null)
	  // 初始化Web Worker
	  useEffect(() => {
	    // 创建Web Worker用于执行测试
	    const workerCode = `
	      self.addEventListener('message', (e) => {
	        const { id, code, framework } = e.data;
	        // 模拟测试执行
	        setTimeout(() => {
	          // 随机生成测试结果（70%成功率）
	          const success = Math.random() > 0.3;
	          const duration = Math.floor(Math.random() * 1000) + 200;
	          const coverage = Math.floor(Math.random() * 30) + 70;
	          // 如果失败，生成错误信息和修复建议
	          let error = null;
	          let fixSuggestion = null;
	          if (!success) {
	            const errors = [
	              "Cannot read property 'x' of undefined",
	              "Expected 'true' but received 'false'",
	              "Timeout exceeded",
	              "Element not found",
	              "Assertion error"
	            ];
	            const suggestions = [
	              "Check if the property exists before accessing it",
	              "Verify the expected value matches the actual value",
	              "Increase the timeout value or optimize the test",
	              "Ensure the element is rendered before accessing it",
	              "Review the assertion logic"
	            ];
	            const errorIndex = Math.floor(Math.random() * errors.length);
	            error = errors[errorIndex];
	            fixSuggestion = suggestions[errorIndex];
	          }
	          self.postMessage({
	            id,
	            result: {
	              status: success ? "passed" : "failed",
	              duration,
	              coverage,
	              error,
	              fixSuggestion
	            }
	          });
	        }, duration);
	      });
	    `;
	    const blob = new Blob([workerCode], { type: 'application/javascript' });
	    const workerUrl = URL.createObjectURL(blob);
	    testWorkerRef.current = new Worker(workerUrl);
	    // 监听Worker消息
	    testWorkerRef.current.addEventListener('message', (e) => {
	      const { id, result } = e.data;
	      // 更新测试结果
	      setTestSuites(prev => {
	        const updatedSuites = [...prev];
	        const suiteIndex = updatedSuites.findIndex(s => s.id === selectedSuite);
	        if (suiteIndex !== -1) {
	          const suite = updatedSuites[suiteIndex];
	          const testIndex = suite.tests.findIndex(t => t.id === id);
	          if (testIndex !== -1) {
	            suite.tests[testIndex] = {
	              ...suite.tests[testIndex],
	              status: result.status,
	              duration: result.duration,
	              coverage: result.coverage,
	              error: result.error,
	              fixSuggestion: result.fixSuggestion
	            };
	            // 更新套件统计信息
	            const passedTests = suite.tests.filter(t => t.status === "passed").length;
	            const failedTests = suite.tests.filter(t => t.status === "failed").length;
	            const totalDuration = suite.tests.reduce((sum, t) => sum + t.duration, 0);
	            const avgCoverage = suite.tests.reduce((sum, t) => sum + t.coverage, 0) / suite.tests.length;
	            suite.passedTests = passedTests;
	            suite.failedTests = failedTests;
	            suite.duration = totalDuration;
	            suite.coverage = Math.floor(avgCoverage);
	          }
	        }
	        return updatedSuites;
	      });
	    });
	    return () => {
	      if (testWorkerRef.current) {
	        testWorkerRef.current.terminate();
	      }
	    };
	  }, [selectedSuite]);
	  // 测试模板 - 扩展支持更多框架
	  const testTemplates = {
	    unit: {
	      jest: `import { render, screen, fireEvent } from '@testing-library/react'
	import { {{ComponentName}} } from './{{ComponentName}}'
	describe('{{ComponentName}}', () => {
	  it('should render correctly', () => {
	    render(<{{ComponentName}} />)
	    expect(screen.getByRole('{{role}}')).toBeInTheDocument()
	  })
	  it('should handle user interactions', () => {
	    const mockHandler = jest.fn()
	    render(<{{ComponentName}} onClick={mockHandler} />)
	    fireEvent.click(screen.getByRole('button'))
	    expect(mockHandler).toHaveBeenCalledTimes(1)
	  })
	  it('should display correct content', () => {
	    const props = { title: 'Test Title' }
	    render(<{{ComponentName}} {...props} />)
	    expect(screen.getByText('Test Title')).toBeInTheDocument()
	  })
	})`,
	      vitest: `import { describe, it, expect, vi } from 'vitest'
	import { render, screen, fireEvent } from '@testing-library/react'
	import { {{ComponentName}} } from './{{ComponentName}}'
	describe('{{ComponentName}}', () => {
	  it('should render without crashing', () => {
	    render(<{{ComponentName}} />)
	    expect(screen.getByTestId('{{testId}}')).toBeDefined()
	  })
	  it('should handle props correctly', () => {
	    const props = { disabled: true }
	    render(<{{ComponentName}} {...props} />)
	    expect(screen.getByRole('button')).toBeDisabled()
	  })
	})`,
	      mocha: `import { expect } from 'chai'
	import { render, screen, fireEvent } from '@testing-library/react'
	import { {{ComponentName}} } from './{{ComponentName}}'
	describe('{{ComponentName}}', () => {
	  it('should render correctly', () => {
	    render(<{{ComponentName}} />)
	    expect(screen.getByRole('{{role}}')).to.exist
	  })
	  it('should handle user interactions', () => {
	    const mockHandler = sinon.spy()
	    render(<{{ComponentName}} onClick={mockHandler} />)
	    fireEvent.click(screen.getByRole('button'))
	    expect(mockHandler.calledOnce).to.be.true
	  })
	})`,
	      jasmine: `describe('{{ComponentName}}', () => {
	  it('should render correctly', () => {
	    const { container } = render(<{{ComponentName}} />)
	    expect(container.querySelector('.{{className}}')).toBeTruthy()
	  })
	  it('should handle user interactions', () => {
	    const mockHandler = jasmine.createSpy('handler')
	    const { getByRole } = render(<{{ComponentName}} onClick={mockHandler} />)
	    fireEvent.click(getByRole('button'))
	    expect(mockHandler).toHaveBeenCalledTimes(1)
	  })
	})`,
	    },
	    integration: {
	      jest: `import { render, screen, waitFor } from '@testing-library/react'
	import userEvent from '@testing-library/user-event'
	import { {{ComponentName}} } from './{{ComponentName}}'
	import { fetchData } from './api'
	jest.mock('./api')
	describe('{{ComponentName}} Integration Tests', () => {
	  beforeEach(() => {
	    (fetchData as jest.Mock).mockResolvedValue({ data: 'mocked data' })
	  })
	  it('should fetch and display data', async () => {
	    render(<{{ComponentName}} />)
	    await waitFor(() => {
	      expect(screen.getByText('mocked data')).toBeInTheDocument()
	    })
	    expect(fetchData).toHaveBeenCalledTimes(1)
	  })
	  it('should handle form submission', async () => {
	    render(<{{ComponentName}} />)
	    await userEvent.type(screen.getByRole('textbox'), 'test input')
	    await userEvent.click(screen.getByRole('button', { name: 'Submit' }))
	    await waitFor(() => {
	      expect(screen.getByText('Submitted: test input')).toBeInTheDocument()
	    })
	  })
	})`,
	      vitest: `import { describe, it, expect, vi } from 'vitest'
	import { render, screen, waitFor } from '@testing-library/react'
	import userEvent from '@testing-library/user-event'
	import { {{ComponentName}} } from './{{ComponentName}}'
	import { fetchData } from './api'
	vi.mock('./api')
	describe('{{ComponentName}} Integration Tests', () => {
	  beforeEach(() => {
	    (fetchData as vi.Mock).mockResolvedValue({ data: 'mocked data' })
	  })
	  it('should render with initial state', () => {
	    render(<{{ComponentName}} />)
	    expect(screen.getByText('Loading...')).toBeInTheDocument()
	  })
	  it('should update state after data fetch', async () => {
	    render(<{{ComponentName}} />)
	    await waitFor(() => {
	      expect(screen.getByText('mocked data')).toBeInTheDocument()
	    })
	  })
	})`,
	      mocha: `import { expect } from 'chai'
	import { render, screen, waitFor } from '@testing-library/react'
	import userEvent from '@testing-library/user-event'
	import { {{ComponentName}} } from './{{ComponentName}}'
	import { fetchData } from './api'
	sinon.stub(fetchData, 'fetchData').resolves({ data: 'mocked data' })
	describe('{{ComponentName}} Integration Tests', () => {
	  afterEach(() => {
	    fetchData.fetchData.restore()
	  })
	  it('should fetch and display data', async () => {
	    render(<{{ComponentName}} />)
	    await waitFor(() => {
	      expect(screen.getByText('mocked data')).to.exist
	    })
	    expect(fetchData.fetchData.calledOnce).to.be.true
	  })
	})`,
	      jasmine: `describe('{{ComponentName}} Integration Tests', () => {
	  let mockFetchData
	  beforeEach(() => {
	    mockFetchData = jasmine.createSpy('fetchData').and.returnValue(
	      Promise.resolve({ data: 'mocked data' })
	    )
	    spyOn(api, 'fetchData').and.callFake(mockFetchData)
	  })
	  it('should fetch and display data', async () => {
	    const { getByText } = render(<{{ComponentName}} />)
	    await waitFor(() => {
	      expect(getByText('mocked data')).toBeTruthy()
	    })
	    expect(mockFetchData).toHaveBeenCalledTimes(1)
	  })
	})`,
	    },
	    e2e: {
	      cypress: `/// <reference types="cypress" />
	describe('{{ComponentName}} E2E Tests', () => {
	  beforeEach(() => {
	    cy.visit('/path/to/{{ComponentName}}')
	  })
	  it('should navigate to page and render component', () => {
	    cy.get('{{selector}}').should('be.visible')
	  })
	  it('should handle user flow', () => {
	    cy.get('{{inputSelector}}').type('Test Value')
	    cy.get('{{buttonSelector}}').click()
	    cy.get('{{resultSelector}}').should('contain.text', 'Test Value')
	  })
	  it('should validate form inputs', () => {
	    cy.get('{{buttonSelector}}').click()
	    cy.get('{{errorSelector}}').should('be.visible')
	    cy.get('{{inputSelector}}').type('Valid Input')
	    cy.get('{{errorSelector}}').should('not.exist')
	  })
	})`,
	      playwright: `import { test, expect } from '@playwright/test'
	test.describe('{{ComponentName}} E2E Tests', () => {
	  test('should load page and display component', async ({ page }) => {
	    await page.goto('/path/to/{{ComponentName}}')
	    await expect(page.locator('{{selector}}')).toBeVisible()
	  })
	  test('should handle form submission', async ({ page }) => {
	    await page.goto('/path/to/{{ComponentName}}')
	    await page.locator('{{inputSelector}}').fill('Test Value')
	    await page.locator('{{buttonSelector}}').click()
	    await expect(page.locator('{{resultSelector}}')).toHaveText('Submitted: Test Value')
	  })
	  test('should handle navigation', async ({ page }) => {
	    await page.goto('/path/to/{{ComponentName}}')
	    await page.locator('{{linkSelector}}').click()
	    await expect(page).toHaveURL('/new-page')
	  })
	})`,
	    },
	    performance: {
	      playwright: `import { test, expect } from '@playwright/test'
	test.describe('{{ComponentName}} Performance Tests', () => {
	  test('should load within performance budget', async ({ page }) => {
	    const start = Date.now()
	    await page.goto('/path/to/{{ComponentName}}')
	    const loadTime = Date.now() - start
	    expect(loadTime).toBeLessThan(2000) // 2 seconds
	  })
	  test('should render components efficiently', async ({ page }) => {
	    await page.goto('/path/to/{{ComponentName}}')
	    await page.evaluate(() => {
	      window.performance.mark('start-render')
	    })
	    await page.locator('{{actionSelector}}').click()
	    await page.evaluate(() => {
	      window.performance.mark('end-render')
	      window.performance.measure('render-time', 'start-render', 'end-render')
	    })
	    const metrics = await page.evaluate(() => {
	      return window.performance.getEntriesByName('render-time')[0]
	    })
	    expect(metrics.duration).toBeLessThan(500) // 500ms
	  })
	})`,
	    },
	    accessibility: {
	      playwright: `import { test, expect } from '@playwright/test'
	import AxeBuilder from '@axe-core/playwright'
	test.describe('{{ComponentName}} Accessibility Tests', () => {
	  test('should have no accessibility violations', async ({ page }) => {
	    await page.goto('/path/to/{{ComponentName}}')
	    const accessibilityScanResults = await new AxeBuilder({ page }).analyze()
	    expect(accessibilityScanResults.violations).toHaveLength(0)
	  })
	  test('should have semantic HTML structure', async ({ page }) => {
	    await page.goto('/path/to/{{ComponentName}}')
	    const pageSource = await page.content()
	    // Check for proper heading structure
	    const headings = pageSource.match(/<h[1-6][^>]*>/g) || []
	    expect(headings.length).toBeGreaterThan(0)
	    // Check for ARIA roles
	    expect(pageSource).toContain('role=')
	  })
	})`,
	    },
	  }
	  // 使用AST解析提取组件名称
	  const extractComponentName = (code: string) => {
	    try {
	      // 模拟AST解析 - 实际项目中应使用@babel/parser
	      const functionRegex = /export\s+(default\s+)?function\s+(\w+)|export\s+const\s+(\w+)\s*=\s*(\(|\()/g
	      const classRegex = /export\s+(default\s+)?class\s+(\w+)|export\s+class\s+(\w+)/g
	      const functionMatch = functionRegex.exec(code)
	      const classMatch = classRegex.exec(code)
	      if (functionMatch) {
	        return functionMatch[2] || functionMatch[3]
	      }
	      if (classMatch) {
	        return classMatch[2] || classMatch[3]
	      }
	      // 如果没有找到，尝试使用箭头函数
	      const arrowFunctionRegex = /export\s+(default\s+)?const\s+(\w+)\s*=\s*\(/g
	      const arrowMatch = arrowFunctionRegex.exec(code)
	      if (arrowMatch) {
	        return arrowMatch[2]
	      }
	      return "Component"
	    } catch (error) {
	      console.error("Error parsing component code:", error)
	      return "Component"
	    }
	  }
	  // 生成测试代码
	  const generateTestCode = (componentCode: string, testType: string) => {
	    const componentName = extractComponentName(componentCode)
	    const framework = config.framework
	    if (!testTemplates[testType as keyof typeof testTemplates]) {
	      return "Unsupported test type"
	    }
	    if (!testTemplates[testType as keyof typeof testTemplates][framework]) {
	      return "Unsupported framework for this test type"
	    }
	    let template = testTemplates[testType as keyof typeof testTemplates][framework]
	    // 替换模板变量
	    template = template
	      .replace(/{{ComponentName}}/g, componentName)
	      .replace(/{{role}}/g, "button")
	      .replace(/{{testId}}/g, "test-id")
	      .replace(/{{className}}/g, componentName.toLowerCase())
	      .replace(/{{selector}}/g, `[data-testid="${componentName.toLowerCase()}"]`)
	      .replace(/{{inputSelector}}/g, 'input[type="text"]')
	      .replace(/{{buttonSelector}}/g, 'button[type="submit"]')
	      .replace(/{{resultSelector}}/g, '[data-testid="result"]')
	      .replace(/{{errorSelector}}/g, '.error-message')
	      .replace(/{{linkSelector}}/g, 'a[href="/new-page"]')
	      .replace(/{{actionSelector}}/g, '[data-testid="action-button"]')
	    return template
	  }
	  // 保存测试代码到文件
	  const saveTestCode = (testCode: string, fileName: string) => {
	    const blob = new Blob([testCode], { type: 'text/javascript' })
	    const url = URL.createObjectURL(blob)
	    const a = document.createElement('a')
	    a.href = url
	    a.download = fileName
	    document.body.appendChild(a)
	    a.click()
	    document.body.removeChild(a)
	    URL.revokeObjectURL(url)
	    toast({
	      title: '文件保存成功',
	      description: `测试代码已保存到 ${fileName}`,
	      variant: 'success',
	    })
	  }
	  // 批量导出测试代码
	  const exportAllTests = () => {
	    if (!selectedSuite) {
	      toast({
	        title: '错误',
	        description: '请先选择一个测试套件',
	        variant: 'destructive',
	      })
	      return
	    }
	    const suite = testSuites.find(s => s.id === selectedSuite)
	    if (!suite) return
	    // 创建ZIP文件（模拟）
	    const files = suite.tests.map(test => ({
	      name: `${test.name.replace(/\s+/g, '_')}.${config.framework === 'jest' || config.framework === 'vitest' ? 'test.js' : 'spec.js'}`,
	      content: test.code
	    }))
	    // 在实际项目中，这里应该使用JSZip等库创建ZIP文件
	    // 这里我们只保存第一个文件作为示例
	    if (files.length > 0) {
	      saveTestCode(files[0].content, files[0].name)
	    }
	    toast({
	      title: '导出成功',
	      description: `已导出 ${files.length} 个测试文件`,
	      variant: 'success',
	    })
	  }
	  // 生成CI/CD配置
	  const generateCiConfig = (type: "github" | "gitlab" | "jenkins" | "azure") => {
	    let ymlContent = ""
	    switch (type) {
	      case "github":
	        ymlContent = `name: Automated Tests
	on:
	  push:
	    branches: [ main ]
	  pull_request:
	    branches: [ main ]
	jobs:
	  test:
	    runs-on: ubuntu-latest
	    strategy:
	      matrix:
	        node-version: [16.x, 18.x]
	    steps:
	    - uses: actions/checkout@v3
	    - name: Use Node.js \${{ matrix.node-version }}
	      uses: actions/setup-node@v3
	      with:
	        node-version: \${{ matrix.node-version }}
	        cache: 'npm'
	    - name: Install dependencies
	      run: npm ci
	    - name: Run tests
	      run: npm test
	    - name: Upload coverage
	      uses: codecov/codecov-action@v3
	      with:
	        file: ./coverage/lcov.info
	        flags: unittests
	        name: codecov-umbrella`
	        break
	      case "gitlab":
	        ymlContent = `stages:
	  - test
	  - deploy
	test:
	  stage: test
	  image: node:18
	  script:
	    - npm ci
	    - npm run test:ci
	  coverage: '/Lines\\s*:\\s*(\\d+\\.\\d+)%/'
	  artifacts:
	    reports:
	      coverage_report:
	        coverage_format: cobertura
	        path: coverage/cobertura-coverage.xml
	      junit:
	        path: junit.xml
	    paths:
	      - coverage/
	    expire_in: 1 week`
	        break
	      case "jenkins":
	        ymlContent = `pipeline {
	    agent any
	    environment {
	        NODE_VERSION = '18'
	    }
	    stages {
	        stage('Install Dependencies') {
	            steps {
	                sh 'npm ci'
	            }
	        }
	        stage('Run Tests') {
	            steps {
	                sh 'npm test'
	            }
	            post {
	                always {
	                    publishHTML([
	                        allowMissing: false,
	                        alwaysLinkToLastBuild: true,
	                        keepAll: true,
	                        reportDir: 'coverage',
	                        reportFiles: 'index.html',
	                        reportName: 'Coverage Report'
	                    ])
	                    junit 'junit.xml'
	                }
	            }
	        }
	    }
	    post {
	        always {
	            cleanWs()
	        }
	    }
	}`
	        break
	      case "azure":
	        ymlContent = `trigger:
	- main
	pool:
	  vmImage: ubuntu-latest
	variables:
	  NODE_VERSION: '18.x'
	steps:
	- task: NodeTool@0
	  inputs:
	    versionSpec: $(NODE_VERSION)
	  displayName: 'Install Node.js'
	- script: |
	    npm ci
	  displayName: 'npm install'
	- script: |
	    npm run test:ci
	  displayName: 'npm test'
	- task: PublishTestResults@2
	  inputs:
	    testResultsFormat: 'JUnit'
	    testResultsFiles: 'junit.xml'
	    failTaskOnFailedTests: true
	  displayName: 'Publish test results'
	- task: PublishCodeCoverageResults@1
	  inputs:
	    codeCoverageTool: 'Cobertura'
	    summaryFileLocation: 'coverage/cobertura-coverage.xml'
	    reportDirectory: 'coverage'
	  displayName: 'Publish code coverage'`
	        break
	    }
	    setCiConfig({
	      type,
	      ymlContent
	    })
	    setShowCiConfig(true)
	    toast({
	      title: 'CI/CD配置生成成功',
	      description: `已生成${type}配置文件`,
	      variant: 'success',
	    })
	  }
	  // 保存CI/CD配置
	  const saveCiConfig = () => {
	    if (!ciConfig) return
	    const fileName = `${ciConfig.type}-ci.yml`
	    saveTestCode(ciConfig.ymlContent, fileName)
	  }
	  // 生成测试套件
	  const handleGenerateTests = async () => {
	    if (!componentCode.trim()) {
	      toast({
	        title: '错误',
	        description: '请输入组件代码',
	        variant: 'destructive',
	      })
	      return
	    }
	    setIsGenerating(true)
	    setGenerationProgress(0)
	    try {
	      // 创建测试套件
	      const suiteId = crypto.randomUUID()
	      const componentName = extractComponentName(componentCode)
	      const newSuite: TestSuite = {
	        id: suiteId,
	        name: `${componentName} Tests`,
	        tests: [],
	        totalTests: config.testTypes.length,
	        passedTests: 0,
	        failedTests: 0,
	        coverage: 0,
	        duration: 0,
	        createdAt: new Date(),
	        componentCode,
	        config: { ...config }
	      }
	      // 为每种测试类型生成测试用例
	      const tests: TestCase[] = []
	      for (let i = 0; i < config.testTypes.length; i++) {
	        const testType = config.testTypes[i]
	        const testId = crypto.randomUUID()
	        const testCase: TestCase = {
	          id: testId,
	          name: `${componentName} ${testType.charAt(0).toUpperCase() + testType.slice(1)} Tests`,
	          type: testType as TestCase["type"],
	          status: "pending",
	          duration: 0,
	          code: generateTestCode(componentCode, testType),
	          description: `Automatically generated ${testType} tests for ${componentName}`,
	          assertions: testType === "unit" ? 3 : testType === "integration" ? 2 : 1,
	          coverage: 0,
	        }
	        tests.push(testCase)
	        setGenerationProgress(((i + 1) / config.testTypes.length) * 100)
	      }
	      newSuite.tests = tests
	      // 更新状态
	      setTestSuites(prev => [...prev, newSuite])
	      setSelectedSuite(suiteId)
	      toast({
	        title: '测试生成成功',
	        description: `为 ${componentName} 组件生成了 ${config.testTypes.length} 种测试`,
	        variant: 'success',
	      })
	    } catch (error) {
	      console.error("Error generating tests:", error)
	      toast({
	        title: '生成测试失败',
	        description: '生成测试时发生错误',
	        variant: 'destructive',
	      })
	    } finally {
	      setIsGenerating(false)
	    }
	  }
	  // 运行测试
	  const handleRunTests = async () => {
	    if (!selectedSuite) {
	      toast({
	        title: '错误',
	        description: '请先选择或生成测试套件',
	        variant: 'destructive',
	      })
	      return
	    }
	    setIsRunning(true)
	    setRunProgress(0)
	    try {
	      const suite = testSuites.find(s => s.id === selectedSuite)
	      if (!suite) return
	      // 重置测试状态
	      const updatedSuites = [...testSuites]
	      const suiteIndex = updatedSuites.findIndex(s => s.id === selectedSuite)
	      if (suiteIndex === -1) return
	      // 重置所有测试为pending状态
	      updatedSuites[suiteIndex].tests = updatedSuites[suiteIndex].tests.map(test => ({
	        ...test,
	        status: "pending",
	        duration: 0,
	        coverage: 0,
	        error: undefined,
	        fixSuggestion: undefined
	      }))
	      updatedSuites[suiteIndex].passedTests = 0
	      updatedSuites[suiteIndex].failedTests = 0
	      updatedSuites[suiteIndex].duration = 0
	      updatedSuites[suiteIndex].coverage = 0
	      setTestSuites(updatedSuites)
	      // 使用Web Worker执行测试
	      const tests = updatedSuites[suiteIndex].tests
	      for (let i = 0; i < tests.length; i++) {
	        const test = tests[i]
	        // 更新测试状态为running
	        setTestSuites(prev => {
	          const updated = [...prev]
	          const idx = updated.findIndex(s => s.id === selectedSuite)
	          if (idx !== -1) {
	            updated[idx].tests[i].status = "running"
	          }
	          return updated
	        })
	        // 发送测试到Worker执行
	        if (testWorkerRef.current) {
	          testWorkerRef.current.postMessage({
	            id: test.id,
	            code: test.code,
	            framework: config.framework
	          })
	        }
	        setRunProgress(((i + 1) / tests.length) * 100)
	        // 等待测试完成
	        await new Promise(resolve => setTimeout(resolve, 100))
	      }
	      // 记录测试历史
	      const suite = testSuites.find(s => s.id === selectedSuite)
	      if (suite) {
	        const historyEntry: TestHistory = {
	          id: crypto.randomUUID(),
	          suiteId: selectedSuite,
	          timestamp: new Date(),
	          results: {
	            passed: suite.passedTests,
	            failed: suite.failedTests,
	            coverage: suite.coverage,
	            duration: suite.duration
	          }
	        }
	        setTestHistory(prev => [...prev, historyEntry])
	      }
	      toast({
	        title: '测试运行完成',
	        description: `执行了 ${tests.length} 个测试，${suite.passedTests} 个通过，${suite.failedTests} 个失败`,
	        variant: 'success',
	      })
	    } catch (error) {
	      console.error("Error running tests:", error)
	      toast({
	        title: '运行测试失败',
	        description: '运行测试时发生错误',
	        variant: 'destructive',
	      })
	    } finally {
	      setIsRunning(false)
	    }
	  }
	  // 渲染测试结果可视化图表
	  const renderTestCharts = () => {
	    if (!selectedSuite) return null
	    const suite = testSuites.find(s => s.id === selectedSuite)
	    if (!suite) return null
	    // 准备图表数据
	    const statusData = [
	      { name: '通过', value: suite.passedTests, color: '#10B981' },
	      { name: '失败', value: suite.failedTests, color: '#EF4444' },
	      { name: '待运行', value: suite.totalTests - suite.passedTests - suite.failedTests, color: '#9CA3AF' }
	    ]
	    const coverageData = suite.tests.map(test => ({
	      name: test.name.split(' ')[1] || test.name,
	      覆盖率: test.coverage
	    }))
	    const durationData = suite.tests.map(test => ({
	      name: test.name.split(' ')[1] || test.name,
	      耗时: test.duration
	    }))
	    return (
	      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
	        <div className="bg-white rounded-lg shadow p-4">
	          <h3 className="text-lg font-semibold mb-4">测试状态分布</h3>
	          <ResponsiveContainer width="100%" height={250}>
	            <PieChart>
	              <Pie
	                data={statusData}
	                cx="50%"
	                cy="50%"
	                innerRadius={60}
	                outerRadius={80}
	                paddingAngle={5}
	                dataKey="value"
	                label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
	              >
	                {statusData.map((entry, index) => (
	                  <Cell key={`cell-${index}`} fill={entry.color} />
	                ))}
	              </Pie>
	              <Tooltip />
	              <Legend />
	            </PieChart>
	          </ResponsiveContainer>
	        </div>
	        <div className="bg-white rounded-lg shadow p-4">
	          <h3 className="text-lg font-semibold mb-4">代码覆盖率</h3>
	          <ResponsiveContainer width="100%" height={250}>
	            <BarChart data={coverageData}>
	              <CartesianGrid strokeDasharray="3 3" />
	              <XAxis dataKey="name" />
	              <YAxis />
	              <Tooltip />
	              <Legend />
	              <Bar dataKey="覆盖率" fill="#3B82F6" />
	            </BarChart>
	          </ResponsiveContainer>
	        </div>
	        <div className="bg-white rounded-lg shadow p-4 md:col-span-2">
	          <h3 className="text-lg font-semibold mb-4">测试耗时分析</h3>
	          <ResponsiveContainer width="100%" height={250}>
	            <LineChart data={durationData}>
	              <CartesianGrid strokeDasharray="3 3" />
	              <XAxis dataKey="name" />
	              <YAxis />
	              <Tooltip />
	              <Legend />
	              <Line type="monotone" dataKey="耗时" stroke="#8B5CF6" activeDot={{ r: 8 }} />
	            </LineChart>
	          </ResponsiveContainer>
	        </div>
	      </div>
	    )
	  }
	  // 渲染测试历史记录
	  const renderTestHistory = () => {
	    if (testHistory.length === 0) {
	      return (
	        <div className="bg-white rounded-lg shadow p-6 text-center">
	          <p className="text-gray-500">暂无测试历史记录</p>
	        </div>
	      )
	    }
	    // 准备历史数据图表
	    const historyData = testHistory.map(entry => ({
	      date: entry.timestamp.toLocaleDateString(),
	      通过: entry.results.passed,
	      失败: entry.results.failed,
	      覆盖率: entry.results.coverage
	    }))
	    return (
	      <div className="space-y-6">
	        <div className="bg-white rounded-lg shadow p-4">
	          <h3 className="text-lg font-semibold mb-4">测试历史趋势</h3>
	          <ResponsiveContainer width="100%" height={300}>
	            <LineChart data={historyData}>
	              <CartesianGrid strokeDasharray="3 3" />
	              <XAxis dataKey="date" />
	              <YAxis />
	              <Tooltip />
	              <Legend />
	              <Line type="monotone" dataKey="通过" stroke="#10B981" />
	              <Line type="monotone" dataKey="失败" stroke="#EF4444" />
	              <Line type="monotone" dataKey="覆盖率" stroke="#3B82F6" />
	            </LineChart>
	          </ResponsiveContainer>
	        </div>
	        <div className="bg-white rounded-lg shadow p-4">
	          <h3 className="text-lg font-semibold mb-4">历史记录详情</h3>
	          <div className="overflow-x-auto">
	            <table className="min-w-full divide-y divide-gray-200">
	              <thead className="bg-gray-50">
	                <tr>
	                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">时间</th>
	                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">测试套件</th>
	                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">通过</th>
	                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">失败</th>
	                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">覆盖率</th>
	                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">耗时</th>
	                </tr>
	              </thead>
	              <tbody className="bg-white divide-y divide-gray-200">
	                {testHistory.map(entry => {
	                  const suite = testSuites.find(s => s.id === entry.suiteId)
	                  return (
	                    <tr key={entry.id}>
	                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
	                        {entry.timestamp.toLocaleString()}
	                      </td>
	                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
	                        {suite?.name || '未知套件'}
	                      </td>
	                      <td className="px-6 py-4 whitespace-nowrap text-sm text-green-600">
	                        {entry.results.passed}
	                      </td>
	                      <td className="px-6 py-4 whitespace-nowrap text-sm text-red-600">
	                        {entry.results.failed}
	                      </td>
	                      <td className="px-6 py-4 whitespace-nowrap text-sm text-blue-600">
	                        {entry.results.coverage}%
	                      </td>
	                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
	                        {entry.results.duration}ms
	                      </td>
	                    </tr>
	                  )
	                })}
	              </tbody>
	            </table>
	          </div>
	        </div>
	      </div>
	    )
	  }
	  // 渲染测试比较视图
	  const renderTestComparison = () => {
	    if (!compareSuites[0] || !compareSuites[1]) {
	      return (
	        <div className="bg-white rounded-lg shadow p-6 text-center">
	          <p className="text-gray-500">请选择两个测试套件进行比较</p>
	        </div>
	      )
	    }
	    const suite1 = testSuites.find(s => s.id === compareSuites[0])
	    const suite2 = testSuites.find(s => s.id === compareSuites[1])
	    if (!suite1 || !suite2) {
	      return (
	        <div className="bg-white rounded-lg shadow p-6 text-center">
	          <p className="text-gray-500">无法找到选中的测试套件</p>
	        </div>
	      )
	    }
	    // 准备比较数据
	    const comparisonData = [
	      {
	        name: '总测试数',
	        套件1: suite1.totalTests,
	        套件2: suite2.totalTests
	      },
	      {
	        name: '通过测试',
	        套件1: suite1.passedTests,
	        套件2: suite2.passedTests
	      },
	      {
	        name: '失败测试',
	        套件1: suite1.failedTests,
	        套件2: suite2.failedTests
	      },
	      {
	        name: '覆盖率',
	        套件1: suite1.coverage,
	        套件2: suite2.coverage
	      },
	      {
	        name: '总耗时',
	        套件1: suite1.duration,
	        套件2: suite2.duration
	      }
	    ]
	    return (
	      <div className="space-y-6">
	        <div className="bg-white rounded-lg shadow p-4">
	          <h3 className="text-lg font-semibold mb-4">测试套件比较</h3>
	          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
	            <div className="border border-gray-200 rounded-lg p-4">
	              <h4 className="font-medium text-gray-900 mb-2">{suite1.name}</h4>
	              <div className="space-y-1 text-sm">
	                <p>创建时间: {suite1.createdAt.toLocaleString()}</p>
	                <p>框架: {suite1.config.framework}</p>
	                <p>测试类型: {suite1.config.testTypes.join(', ')}</p>
	              </div>
	            </div>
	            <div className="border border-gray-200 rounded-lg p-4">
	              <h4 className="font-medium text-gray-900 mb-2">{suite2.name}</h4>
	              <div className="space-y-1 text-sm">
	                <p>创建时间: {suite2.createdAt.toLocaleString()}</p>
	                <p>框架: {suite2.config.framework}</p>
	                <p>测试类型: {suite2.config.testTypes.join(', ')}</p>
	              </div>
	            </div>
	          </div>
	          <ResponsiveContainer width="100%" height={300}>
	            <BarChart data={comparisonData}>
	              <CartesianGrid strokeDasharray="3 3" />
	              <XAxis dataKey="name" />
	              <YAxis />
	              <Tooltip />
	              <Legend />
	              <Bar dataKey="套件1" fill="#3B82F6" />
	              <Bar dataKey="套件2" fill="#8B5CF6" />
	            </BarChart>
	          </ResponsiveContainer>
	        </div>
	        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
	          <div className="bg-white rounded-lg shadow p-4">
	            <h4 className="font-medium text-gray-900 mb-4">{suite1.name} - 测试详情</h4>
	            <div className="space-y-3">
	              {suite1.tests.map(test => (
	                <div key={test.id} className="border border-gray-200 rounded-lg p-3">
	                  <div className="flex justify-between items-center">
	                    <h5 className="font-medium text-sm">{test.name}</h5>
	                    <span 
	                      className={`px-2 py-0.5 text-xs rounded-full ${
	                        test.status === "passed" ? "bg-green-100 text-green-800" : 
	                        test.status === "failed" ? "bg-red-100 text-red-800" : 
	                        "bg-gray-100 text-gray-800"
	                      }`}
	                    >
	                      {test.status}
	                    </span>
	                  </div>
	                  <div className="mt-2 text-xs text-gray-600">
	                    <p>类型: {test.type}</p>
	                    <p>耗时: {test.duration}ms</p>
	                    <p>覆盖率: {test.coverage}%</p>
	                  </div>
	                </div>
	              ))}
	            </div>
	          </div>
	          <div className="bg-white rounded-lg shadow p-4">
	            <h4 className="font-medium text-gray-900 mb-4">{suite2.name} - 测试详情</h4>
	            <div className="space-y-3">
	              {suite2.tests.map(test => (
	                <div key={test.id} className="border border-gray-200 rounded-lg p-3">
	                  <div className="flex justify-between items-center">
	                    <h5 className="font-medium text-sm">{test.name}</h5>
	                    <span 
	                      className={`px-2 py-0.5 text-xs rounded-full ${
	                        test.status === "passed" ? "bg-green-100 text-green-800" : 
	                        test.status === "failed" ? "bg-red-100 text-red-800" : 
	                        "bg-gray-100 text-gray-800"
	                      }`}
	                    >
	                      {test.status}
	                    </span>
	                  </div>
	                  <div className="mt-2 text-xs text-gray-600">
	                    <p>类型: {test.type}</p>
	                    <p>耗时: {test.duration}ms</p>
	                    <p>覆盖率: {test.coverage}%</p>
	                  </div>
	                </div>
	              ))}
	            </div>
	          </div>
	        </div>
	      </div>
	    )
	  }
	  // 渲染测试结果
	  const renderTestResults = () => {
	    if (!selectedSuite) return <div className="text-gray-500">请生成或选择一个测试套件</div>
	    const suite = testSuites.find(s => s.id === selectedSuite)
	    if (!suite) return <div className="text-gray-500">测试套件未找到</div>
	    return (
	      <div className="mt-6 space-y-4">
	        <div className="bg-white rounded-lg shadow p-4">
	          <div className="flex justify-between items-center mb-4">
	            <h3 className="text-lg font-semibold">{suite.name}</h3>
	            <div className="flex space-x-2">
	              <span className="px-2 py-1 text-xs bg-green-100 text-green-800 rounded-full">
	                通过: {suite.passedTests}
	              </span>
	              <span className="px-2 py-1 text-xs bg-red-100 text-red-800 rounded-full">
	                失败: {suite.failedTests}
	              </span>
	              <span className="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full">
	                覆盖率: {suite.coverage}%
	              </span>
	              <span className="px-2 py-1 text-xs bg-gray-100 text-gray-800 rounded-full">
	                耗时: {suite.duration}ms
	              </span>
	            </div>
	          </div>
	          <div className="flex space-x-3 mb-4">
	            <button
	              onClick={() => setShowHistory(!showHistory)}
	              className="px-3 py-1.5 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors"
	            >
	              {showHistory ? '隐藏历史' : '查看历史'}
	            </button>
	            <button
	              onClick={() => setCompareMode(!compareMode)}
	              className="px-3 py-1.5 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors"
	            >
	              {compareMode ? '退出比较' : '比较套件'}
	            </button>
	            <button
	              onClick={() => setShowCiConfig(!showCiConfig)}
	              className="px-3 py-1.5 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors"
	            >
	              {showCiConfig ? '隐藏配置' : 'CI/CD配置'}
	            </button>
	            <button
	              onClick={exportAllTests}
	              className="px-3 py-1.5 text-sm bg-blue-100 hover:bg-blue-200 text-blue-700 rounded-md transition-colors"
	            >
	              导出测试
	            </button>
	          </div>
	          {showCiConfig && ciConfig && (
	            <div className="mb-6 border border-gray-200 rounded-lg p-4">
	              <div className="flex justify-between items-center mb-3">
	                <h4 className="font-medium">{ciConfig.type.toUpperCase()} CI/CD 配置</h4>
	                <button
	                  onClick={saveCiConfig}
	                  className="px-3 py-1 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded-md transition-colors"
	                >
	                  保存配置
	                </button>
	              </div>
	              <pre className="bg-gray-800 text-gray-100 p-4 rounded-md text-sm overflow-x-auto">
	                {ciConfig.ymlContent}
	              </pre>
	            </div>
	          )}
	          {compareMode && (
	            <div className="mb-6 border border-gray-200 rounded-lg p-4">
	              <h4 className="font-medium mb-3">选择测试套件进行比较</h4>
	              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
	                <div>
	                  <label className="block text-sm font-medium text-gray-700 mb-1">套件 1</label>
	                  <select
	                    value={compareSuites[0] || ""}
	                    onChange={(e) => setCompareSuites([e.target.value || null, compareSuites[1]])}
	                    className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
	                  >
	                    <option value="">选择测试套件</option>
	                    {testSuites.map(suite => (
	                      <option key={suite.id} value={suite.id}>
	                        {suite.name}
	                      </option>
	                    ))}
	                  </select>
	                </div>
	                <div>
	                  <label className="block text-sm font-medium text-gray-700 mb-1">套件 2</label>
	                  <select
	                    value={compareSuites[1] || ""}
	                    onChange={(e) => setCompareSuites([compareSuites[0], e.target.value || null])}
	                    className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
	                  >
	                    <option value="">选择测试套件</option>
	                    {testSuites.map(suite => (
	                      <option key={suite.id} value={suite.id}>
	                        {suite.name}
	                      </option>
	                    ))}
	                  </select>
	                </div>
	              </div>
	              {compareSuites[0] && compareSuites[1] && renderTestComparison()}
	            </div>
	          )}
	          {showHistory && renderTestHistory()}
	          {!showHistory && !compareMode && renderTestCharts()}
	          <div className="space-y-3">
	            {suite.tests.map(test => (
	              <div key={test.id} className="border border-gray-200 rounded-lg p-3 hover:border-blue-300 transition-all">
	                <div className="flex justify-between items-center">
	                  <h4 className="font-medium">{test.name}</h4>
	                  <span 
	                    className={`px-2 py-0.5 text-xs rounded-full ${
	                      test.status === "passed" ? "bg-green-100 text-green-800" : 
	                      test.status === "failed" ? "bg-red-100 text-red-800" : 
	                      test.status === "running" ? "bg-blue-100 text-blue-800" : 
	                      "bg-gray-100 text-gray-800"
	                    }`}
	                  >
	                    {test.status}
	                  </span>
	                </div>
	                <div className="mt-2 text-sm text-gray-600">
	                  <p>类型: {test.type}</p>
	                  <p>断言: {test.assertions}</p>
	                  <p>耗时: {test.duration}ms</p>
	                  <p>覆盖率: {test.coverage}%</p>
	                </div>
	                {test.error && (
	                  <div className="mt-3 p-3 bg-red-50 rounded-md">
	                    <p className="text-sm font-medium text-red-800">错误信息:</p>
	                    <p className="text-sm text-red-700 mt-1">{test.error}</p>
	                    {test.fixSuggestion && (
	                      <div className="mt-2">
	                        <p className="text-sm font-medium text-blue-800">修复建议:</p>
	                        <p className="text-sm text-blue-700 mt-1">{test.fixSuggestion}</p>
	                      </div>
	                    )}
	                  </div>
	                )}
	                <div className="mt-3 flex space-x-2">
	                  <button 
	                    className="text-blue-600 hover:text-blue-800 text-sm font-medium"
	                    onClick={() => navigator.clipboard.writeText(test.code)}
	                  >
	                    复制测试代码
	                  </button>
	                  <button 
	                    className="text-green-600 hover:text-green-800 text-sm font-medium"
	                    onClick={() => saveTestCode(test.code, `${test.name.replace(/\s+/g, '_')}.${config.framework === 'jest' || config.framework === 'vitest' ? 'test.js' : 'spec.js'}`)}
	                  >
	                    保存文件
	                  </button>
	                </div>
	              </div>
	            ))}
	          </div>
	        </div>
	      </div>
	    )
	  }
	  return (
	    <div className="max-w-6xl mx-auto p-4 md:p-6">
	      <h1 className="text-[clamp(1.5rem,3vw,2.5rem)] font-bold text-gray-900 mb-6">自动化测试生成器</h1>
	      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
	        {/* 左侧面板：配置和控制 */}
	        <div className="lg:col-span-1 space-y-6">
	          <div className="bg-white rounded-xl shadow p-5">
	            <h2 className="text-lg font-semibold mb-4">测试配置</h2>
	            <div className="space-y-4">
	              <div>
	                <label className="block text-sm font-medium text-gray-700 mb-1">测试框架</label>
	                <select
	                  value={config.framework}
	                  onChange={(e) => setConfig({ ...config, framework: e.target.value as TestGenerationConfig["framework"] })}
	                  className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
	                >
	                  <option value="jest">Jest</option>
	                  <option value="vitest">Vitest</option>
	                  <option value="cypress">Cypress</option>
	                  <option value="playwright">Playwright</option>
	                  <option value="mocha">Mocha</option>
	                                   <option value="jasmine">Jasmine</option>
	                </select>
	              </div>
	              <div>
	                <label className="block text-sm font-medium text-gray-700 mb-1">测试类型</label>
	                <div className="space-y-2">
	                  <label className="flex items-center">
	                    <input
	                      type="checkbox"
	                      checked={config.testTypes.includes("unit")}
	                      onChange={(e) => {
	                        setConfig({
	                          ...config,
	                          testTypes: e.target.checked
	                            ? [...config.testTypes, "unit"]
	                            : config.testTypes.filter(t => t !== "unit"),
	                        })
	                      }}
	                      className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-gray-300 rounded"
	                    />
	                    <span className="ml-2 text-sm text-gray-700">单元测试</span>
	                  </label>
	                  <label className="flex items-center">
	                    <input
	                      type="checkbox"
	                      checked={config.testTypes.includes("integration")}
	                      onChange={(e) => {
	                        setConfig({
	                          ...config,
	                          testTypes: e.target.checked
	                            ? [...config.testTypes, "integration"]
	                            : config.testTypes.filter(t => t !== "integration"),
	                        })
	                      }}
	                      className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-gray-300 rounded"
	                    />
	                    <span className="ml-2 text-sm text-gray-700">集成测试</span>
	                  </label>
	                  <label className="flex items-center">
	                    <input
	                      type="checkbox"
	                      checked={config.testTypes.includes("e2e")}
	                      onChange={(e) => {
	                        setConfig({
	                          ...config,
	                          testTypes: e.target.checked
	                            ? [...config.testTypes, "e2e"]
	                            : config.testTypes.filter(t => t !== "e2e"),
	                        })
	                      }}
	                      className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-gray-300 rounded"
	                    />
	                    <span className="ml-2 text-sm text-gray-700">端到端测试</span>
	                  </label>
	                  <label className="flex items-center">
	                    <input
	                      type="checkbox"
	                      checked={config.testTypes.includes("performance")}
	                      onChange={(e) => {
	                        setConfig({
	                          ...config,
	                          testTypes: e.target.checked
	                            ? [...config.testTypes, "performance"]
	                            : config.testTypes.filter(t => t !== "performance"),
	                        })
	                      }}
	                      className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-gray-300 rounded"
	                    />
	                    <span className="ml-2 text-sm text-gray-700">性能测试</span>
	                  </label>
	                  <label className="flex items-center">
	                    <input
	                      type="checkbox"
	                      checked={config.testTypes.includes("accessibility")}
	                      onChange={(e) => {
	                        setConfig({
	                          ...config,
	                          testTypes: e.target.checked
	                            ? [...config.testTypes, "accessibility"]
	                            : config.testTypes.filter(t => t !== "accessibility"),
	                        })
	                      }}
	                      className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-gray-300 rounded"
	                    />
	                    <span className="ml-2 text-sm text-gray-700">可访问性测试</span>
	                  </label>
	                </div>
	              </div>
	              <div className="space-y-2">
	                <label className="block text-sm font-medium text-gray-700 mb-1">附加选项</label>
	                <label className="flex items-center">
	                  <input
	                    type="checkbox"
	                    checked={config.coverage}
	                    onChange={(e) => setConfig({ ...config, coverage: e.target.checked })}
	                    className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-gray-300 rounded"
	                  />
	                  <span className="ml-2 text-sm text-gray-700">代码覆盖率</span>
	                </label>
	                <label className="flex items-center">
	                  <input
	                    type="checkbox"
	                    checked={config.mocking}
	                    onChange={(e) => setConfig({ ...config, mocking: e.target.checked })}
	                    className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-gray-300 rounded"
	                  />
	                  <span className="ml-2 text-sm text-gray-700">自动模拟</span>
	                </label>
	                <label className="flex items-center">
	                  <input
	                    type="checkbox"
	                    checked={config.visualRegression}
	                    onChange={(e) => setConfig({ ...config, visualRegression: e.target.checked })}
	                    className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-gray-300 rounded"
	                  />
	                  <span className="ml-2 text-sm text-gray-700">视觉回归测试</span>
	                </label>
	              </div>
	              <div className="pt-2">
	                <label className="block text-sm font-medium text-gray-700 mb-1">CI/CD 配置</label>
	                <div className="grid grid-cols-2 gap-2">
	                  <button
	                    onClick={() => generateCiConfig("github")}
	                    className="px-3 py-2 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors"
	                  >
	                    GitHub
	                  </button>
	                  <button
	                    onClick={() => generateCiConfig("gitlab")}
	                    className="px-3 py-2 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors"
	                  >
	                    GitLab
	                  </button>
	                  <button
	                    onClick={() => generateCiConfig("jenkins")}
	                    className="px-3 py-2 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors"
	                  >
	                    Jenkins
	                  </button>
	                  <button
	                    onClick={() => generateCiConfig("azure")}
	                    className="px-3 py-2 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors"
	                  >
	                    Azure
	                  </button>
	                </div>
	              </div>
	            </div>
	          </div>
	          <div className="bg-white rounded-xl shadow p-5">
	            <h2 className="text-lg font-semibold mb-4">组件代码</h2>
	            <div className="mb-4">
	              <textarea
	                value={componentCode}
	                onChange={(e) => setComponentCode(e.target.value)}
	                rows={10}
	                placeholder="在此粘贴你的React组件代码..."
	                className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
	              />
	            </div>
	            <div className="flex space-x-3">
	              <button
	                onClick={handleGenerateTests}
	                disabled={isGenerating || isRunning}
	                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
	              >
	                {isGenerating ? (
	                  <div className="flex items-center justify-center">
	                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin mr-2"></div>
	                    生成中 ({Math.round(generationProgress)}%)
	                  </div>
	                ) : (
	                  "生成测试"
	                )}
	              </button>
	              <button
	                onClick={handleRunTests}
	                disabled={!selectedSuite || isGenerating || isRunning}
	                className="flex-1 bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-md transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
	              >
	                {isRunning ? (
	                  <div className="flex items-center justify-center">
	                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin mr-2"></div>
	                    运行中 ({Math.round(runProgress)}%)
	                  </div>
	                ) : (
	                  "运行测试"
	                )}
	              </button>
	            </div>
	          </div>
	        </div>
	        {/* 右侧面板：测试结果 */}
	        <div className="lg:col-span-2">
	          <div className="bg-white rounded-xl shadow p-5">
	            <div className="flex justify-between items-center mb-4">
	              <h2 className="text-lg font-semibold">测试套件</h2>
	              <select
	                value={selectedSuite || ""}
	                onChange={(e) => setSelectedSuite(e.target.value || null)}
	                className="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
	              >
	                <option value="">选择测试套件</option>
	                {testSuites.map(suite => (
	                  <option key={suite.id} value={suite.id}>
	                    {suite.name} - {suite.passedTests}/{suite.totalTests} 通过
	                  </option>
	                ))}
	              </select>
	            </div>
	            {renderTestResults()}
	          </div>
	        </div>
	      </div>
	    </div>
	  )
	}