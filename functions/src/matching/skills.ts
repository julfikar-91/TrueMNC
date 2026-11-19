// functions/src/matching/skills.ts
// Central skills taxonomy dictionary and normalization service.
// At least 150 canonical skills categorized and grouped.

export type SkillCategory =
  | "language"
  | "framework"
  | "db"
  | "cloud"
  | "tool"
  | "soft";

export interface SkillEntry {
  canonicalId: string;
  name: string;
  category: SkillCategory;
  relatedGroupId: string;
  aliases: string[];
}

export const SKILLS_DICTIONARY: SkillEntry[] = [
  // ── Languages (35) ──────────────────────────────────────────────────────────
  {
    canonicalId: "javascript",
    name: "JavaScript",
    category: "language",
    relatedGroupId: "web-scripting",
    aliases: ["js", "javascript", "java script", "ecmascript", "es6", "es2020", "esnext"],
  },
  {
    canonicalId: "typescript",
    name: "TypeScript",
    category: "language",
    relatedGroupId: "typed-lang",
    aliases: ["ts", "typescript", "type script"],
  },
  {
    canonicalId: "python",
    name: "Python",
    category: "language",
    relatedGroupId: "python-lang",
    aliases: ["python", "py", "python3", "python 3", "python2"],
  },
  {
    canonicalId: "dart",
    name: "Dart",
    category: "language",
    relatedGroupId: "mobile-lang",
    aliases: ["dart", "dartlang", "dart lang"],
  },
  {
    canonicalId: "kotlin",
    name: "Kotlin",
    category: "language",
    relatedGroupId: "jvm-lang",
    aliases: ["kotlin", "kt"],
  },
  {
    canonicalId: "java",
    name: "Java",
    category: "language",
    relatedGroupId: "jvm-lang",
    aliases: ["java", "java8", "java 11", "java 17", "java 21", "core java"],
  },
  {
    canonicalId: "swift",
    name: "Swift",
    category: "language",
    relatedGroupId: "apple-lang",
    aliases: ["swift", "swiftlang"],
  },
  {
    canonicalId: "objective-c",
    name: "Objective-C",
    category: "language",
    relatedGroupId: "apple-lang",
    aliases: ["objective-c", "objc", "obj-c", "objective c"],
  },
  {
    canonicalId: "go",
    name: "Go",
    category: "language",
    relatedGroupId: "compiled-lang",
    aliases: ["go", "golang", "go-lang", "go lang"],
  },
  {
    canonicalId: "rust",
    name: "Rust",
    category: "language",
    relatedGroupId: "systems-lang",
    aliases: ["rust", "rustlang"],
  },
  {
    canonicalId: "cpp",
    name: "C++",
    category: "language",
    relatedGroupId: "systems-lang",
    aliases: ["c++", "cpp", "c plus plus"],
  },
  {
    canonicalId: "c",
    name: "C",
    category: "language",
    relatedGroupId: "systems-lang",
    aliases: ["c lang", "c language", "c-lang"],
  },
  {
    canonicalId: "csharp",
    name: "C#",
    category: "language",
    relatedGroupId: "dotnet-lang",
    aliases: ["c#", "csharp", "c-sharp", "c sharp"],
  },
  {
    canonicalId: "php",
    name: "PHP",
    category: "language",
    relatedGroupId: "web-scripting",
    aliases: ["php", "php7", "php8"],
  },
  {
    canonicalId: "ruby",
    name: "Ruby",
    category: "language",
    relatedGroupId: "ruby-lang",
    aliases: ["ruby", "ruby lang"],
  },
  {
    canonicalId: "scala",
    name: "Scala",
    category: "language",
    relatedGroupId: "jvm-lang",
    aliases: ["scala", "scala lang"],
  },
  {
    canonicalId: "r",
    name: "R",
    category: "language",
    relatedGroupId: "data-lang",
    aliases: ["r lang", "r language", "r-lang"],
  },
  {
    canonicalId: "julia",
    name: "Julia",
    category: "language",
    relatedGroupId: "data-lang",
    aliases: ["julia", "julia lang"],
  },
  {
    canonicalId: "shell",
    name: "Shell",
    category: "language",
    relatedGroupId: "scripting-lang",
    aliases: ["sh", "shell", "shell script", "shell scripting"],
  },
  {
    canonicalId: "bash",
    name: "Bash",
    category: "language",
    relatedGroupId: "scripting-lang",
    aliases: ["bash", "bash script", "bash scripting"],
  },
  {
    canonicalId: "powershell",
    name: "PowerShell",
    category: "language",
    relatedGroupId: "scripting-lang",
    aliases: ["powershell", "ps", "posh"],
  },
  {
    canonicalId: "sql",
    name: "SQL",
    category: "language",
    relatedGroupId: "sql-db",
    aliases: ["sql", "structured query language", "ansi sql"],
  },
  {
    canonicalId: "html",
    name: "HTML",
    category: "language",
    relatedGroupId: "web-markup",
    aliases: ["html", "html5", "html 5"],
  },
  {
    canonicalId: "css",
    name: "CSS",
    category: "language",
    relatedGroupId: "web-styling",
    aliases: ["css", "css3", "css 3"],
  },
  {
    canonicalId: "sass",
    name: "Sass",
    category: "language",
    relatedGroupId: "web-styling",
    aliases: ["sass", "scss"],
  },
  {
    canonicalId: "graphql",
    name: "GraphQL",
    category: "language",
    relatedGroupId: "api-query",
    aliases: ["graphql", "graph ql", "gql"],
  },
  {
    canonicalId: "solidity",
    name: "Solidity",
    category: "language",
    relatedGroupId: "blockchain-lang",
    aliases: ["solidity", "smart contracts"],
  },
  {
    canonicalId: "elixir",
    name: "Elixir",
    category: "language",
    relatedGroupId: "erlang-beam",
    aliases: ["elixir", "elixirlang"],
  },
  {
    canonicalId: "clojure",
    name: "Clojure",
    category: "language",
    relatedGroupId: "jvm-lang",
    aliases: ["clojure", "clj"],
  },
  {
    canonicalId: "haskell",
    name: "Haskell",
    category: "language",
    relatedGroupId: "functional-lang",
    aliases: ["haskell", "ghc"],
  },
  {
    canonicalId: "perl",
    name: "Perl",
    category: "language",
    relatedGroupId: "scripting-lang",
    aliases: ["perl", "perl5"],
  },
  {
    canonicalId: "matlab",
    name: "MATLAB",
    category: "language",
    relatedGroupId: "data-lang",
    aliases: ["matlab", "mathworks matlab"],
  },
  {
    canonicalId: "assembly",
    name: "Assembly",
    category: "language",
    relatedGroupId: "low-level",
    aliases: ["assembly", "asm", "x86", "arm asm"],
  },
  {
    canonicalId: "lua",
    name: "Lua",
    category: "language",
    relatedGroupId: "scripting-lang",
    aliases: ["lua", "luajit"],
  },
  {
    canonicalId: "groovy",
    name: "Groovy",
    category: "language",
    relatedGroupId: "jvm-lang",
    aliases: ["groovy", "apache groovy"],
  },

  // ── Frameworks & Libraries (40) ─────────────────────────────────────────────
  {
    canonicalId: "flutter",
    name: "Flutter",
    category: "framework",
    relatedGroupId: "mobile-cross-platform",
    aliases: ["flutter", "flutter framework", "flutter sdk"],
  },
  {
    canonicalId: "react",
    name: "React",
    category: "framework",
    relatedGroupId: "frontend-spa",
    aliases: ["react", "react.js", "reactjs", "react js"],
  },
  {
    canonicalId: "react-native",
    name: "React Native",
    category: "framework",
    relatedGroupId: "mobile-cross-platform",
    aliases: ["react native", "react-native", "rn"],
  },
  {
    canonicalId: "nextjs",
    name: "Next.js",
    category: "framework",
    relatedGroupId: "frontend-ssr",
    aliases: ["next.js", "nextjs", "next js", "next"],
  },
  {
    canonicalId: "angular",
    name: "Angular",
    category: "framework",
    relatedGroupId: "frontend-spa",
    aliases: ["angular", "angularjs", "angular 2+", "angular.js"],
  },
  {
    canonicalId: "vuejs",
    name: "Vue.js",
    category: "framework",
    relatedGroupId: "frontend-spa",
    aliases: ["vue", "vue.js", "vuejs", "vue 3"],
  },
  {
    canonicalId: "svelte",
    name: "Svelte",
    category: "framework",
    relatedGroupId: "frontend-spa",
    aliases: ["svelte", "sveltekit", "svelte js"],
  },
  {
    canonicalId: "nodejs",
    name: "Node.js",
    category: "framework",
    relatedGroupId: "backend-runtime",
    aliases: ["node", "node.js", "nodejs", "node js"],
  },
  {
    canonicalId: "expressjs",
    name: "Express.js",
    category: "framework",
    relatedGroupId: "backend-node",
    aliases: ["express", "express.js", "expressjs", "express js"],
  },
  {
    canonicalId: "nestjs",
    name: "NestJS",
    category: "framework",
    relatedGroupId: "backend-node",
    aliases: ["nest", "nestjs", "nest.js", "nest js"],
  },
  {
    canonicalId: "django",
    name: "Django",
    category: "framework",
    relatedGroupId: "backend-python",
    aliases: ["django", "django rest framework", "drf"],
  },
  {
    canonicalId: "fastapi",
    name: "FastAPI",
    category: "framework",
    relatedGroupId: "backend-python",
    aliases: ["fastapi", "fast api", "fast-api"],
  },
  {
    canonicalId: "flask",
    name: "Flask",
    category: "framework",
    relatedGroupId: "backend-python",
    aliases: ["flask", "flask python"],
  },
  {
    canonicalId: "spring-boot",
    name: "Spring Boot",
    category: "framework",
    relatedGroupId: "backend-jvm",
    aliases: ["spring", "spring boot", "springboot", "spring framework"],
  },
  {
    canonicalId: "aspnet-core",
    name: "ASP.NET Core",
    category: "framework",
    relatedGroupId: "dotnet-framework",
    aliases: ["asp.net", "asp.net core", "aspnet", "dotnet core", ".net core"],
  },
  {
    canonicalId: "ruby-on-rails",
    name: "Ruby on Rails",
    category: "framework",
    relatedGroupId: "ruby-framework",
    aliases: ["rails", "ruby on rails", "ror"],
  },
  {
    canonicalId: "swiftui",
    name: "SwiftUI",
    category: "framework",
    relatedGroupId: "apple-ui",
    aliases: ["swiftui", "swift ui"],
  },
  {
    canonicalId: "uikit",
    name: "UIKit",
    category: "framework",
    relatedGroupId: "apple-ui",
    aliases: ["uikit", "ui kit"],
  },
  {
    canonicalId: "jetpack-compose",
    name: "Jetpack Compose",
    category: "framework",
    relatedGroupId: "android-ui",
    aliases: ["compose", "jetpack compose", "android compose"],
  },
  {
    canonicalId: "android-sdk",
    name: "Android SDK",
    category: "framework",
    relatedGroupId: "android-core",
    aliases: ["android", "android sdk", "android development"],
  },
  {
    canonicalId: "redux",
    name: "Redux",
    category: "framework",
    relatedGroupId: "state-management",
    aliases: ["redux", "redux toolkit", "rtk"],
  },
  {
    canonicalId: "riverpod",
    name: "Riverpod",
    category: "framework",
    relatedGroupId: "state-management",
    aliases: ["riverpod", "flutter riverpod"],
  },
  {
    canonicalId: "tailwindcss",
    name: "Tailwind CSS",
    category: "framework",
    relatedGroupId: "web-styling",
    aliases: ["tailwind", "tailwindcss", "tailwind css"],
  },
  {
    canonicalId: "bootstrap",
    name: "Bootstrap",
    category: "framework",
    relatedGroupId: "web-styling",
    aliases: ["bootstrap", "bootstrap 5"],
  },
  {
    canonicalId: "pytorch",
    name: "PyTorch",
    category: "framework",
    relatedGroupId: "ml-framework",
    aliases: ["pytorch", "torch"],
  },
  {
    canonicalId: "tensorflow",
    name: "TensorFlow",
    category: "framework",
    relatedGroupId: "ml-framework",
    aliases: ["tensorflow", "tf", "tensor flow"],
  },
  {
    canonicalId: "scikit-learn",
    name: "scikit-learn",
    category: "framework",
    relatedGroupId: "ml-framework",
    aliases: ["scikit-learn", "sklearn", "scikit learn"],
  },
  {
    canonicalId: "pandas",
    name: "Pandas",
    category: "framework",
    relatedGroupId: "data-analysis",
    aliases: ["pandas", "pd"],
  },
  {
    canonicalId: "numpy",
    name: "NumPy",
    category: "framework",
    relatedGroupId: "data-analysis",
    aliases: ["numpy", "np"],
  },
  {
    canonicalId: "keras",
    name: "Keras",
    category: "framework",
    relatedGroupId: "ml-framework",
    aliases: ["keras"],
  },
  {
    canonicalId: "apache-spark",
    name: "Apache Spark",
    category: "framework",
    relatedGroupId: "big-data",
    aliases: ["spark", "apache spark", "pyspark"],
  },
  {
    canonicalId: "apache-flink",
    name: "Apache Flink",
    category: "framework",
    relatedGroupId: "big-data",
    aliases: ["flink", "apache flink"],
  },
  {
    canonicalId: "apache-kafka",
    name: "Apache Kafka",
    category: "framework",
    relatedGroupId: "message-broker",
    aliases: ["kafka", "apache kafka"],
  },
  {
    canonicalId: "rabbitmq",
    name: "RabbitMQ",
    category: "framework",
    relatedGroupId: "message-broker",
    aliases: ["rabbitmq", "rabbit mq"],
  },
  {
    canonicalId: "grpc",
    name: "gRPC",
    category: "framework",
    relatedGroupId: "rpc-protocols",
    aliases: ["grpc", "g-rpc"],
  },
  {
    canonicalId: "rest-api",
    name: "REST API",
    category: "framework",
    relatedGroupId: "api-architecture",
    aliases: ["rest", "rest api", "restful", "restful api"],
  },
  {
    canonicalId: "websockets",
    name: "WebSockets",
    category: "framework",
    relatedGroupId: "realtime-comms",
    aliases: ["websocket", "websockets", "ws", "socket.io"],
  },
  {
    canonicalId: "junit",
    name: "JUnit",
    category: "framework",
    relatedGroupId: "unit-testing",
    aliases: ["junit", "junit 5"],
  },
  {
    canonicalId: "cypress",
    name: "Cypress",
    category: "framework",
    relatedGroupId: "e2e-testing",
    aliases: ["cypress", "cypress.io"],
  },
  {
    canonicalId: "playwright",
    name: "Playwright",
    category: "framework",
    relatedGroupId: "e2e-testing",
    aliases: ["playwright", "playwright testing"],
  },

  // ── Databases (25) ──────────────────────────────────────────────────────────
  {
    canonicalId: "postgresql",
    name: "PostgreSQL",
    category: "db",
    relatedGroupId: "sql-db",
    aliases: ["postgres", "postgresql", "psql", "postgre sql"],
  },
  {
    canonicalId: "mysql",
    name: "MySQL",
    category: "db",
    relatedGroupId: "sql-db",
    aliases: ["mysql", "my sql"],
  },
  {
    canonicalId: "sqlite",
    name: "SQLite",
    category: "db",
    relatedGroupId: "sql-db",
    aliases: ["sqlite", "sqlite3"],
  },
  {
    canonicalId: "mongodb",
    name: "MongoDB",
    category: "db",
    relatedGroupId: "nosql-db",
    aliases: ["mongo", "mongodb", "mongo db"],
  },
  {
    canonicalId: "redis",
    name: "Redis",
    category: "db",
    relatedGroupId: "in-memory-db",
    aliases: ["redis", "redis cache"],
  },
  {
    canonicalId: "cloud-firestore",
    name: "Cloud Firestore",
    category: "db",
    relatedGroupId: "nosql-db",
    aliases: ["firestore", "cloud firestore", "firebase firestore"],
  },
  {
    canonicalId: "firebase-rtdb",
    name: "Firebase Realtime Database",
    category: "db",
    relatedGroupId: "nosql-db",
    aliases: ["firebase rtdb", "realtime database", "firebase db"],
  },
  {
    canonicalId: "oracle-db",
    name: "Oracle Database",
    category: "db",
    relatedGroupId: "sql-db",
    aliases: ["oracle", "oracle db", "oracle sql"],
  },
  {
    canonicalId: "sql-server",
    name: "Microsoft SQL Server",
    category: "db",
    relatedGroupId: "sql-db",
    aliases: ["mssql", "sql server", "microsoft sql server"],
  },
  {
    canonicalId: "mariadb",
    name: "MariaDB",
    category: "db",
    relatedGroupId: "sql-db",
    aliases: ["mariadb", "maria db"],
  },
  {
    canonicalId: "cassandra",
    name: "Apache Cassandra",
    category: "db",
    relatedGroupId: "nosql-db",
    aliases: ["cassandra", "apache cassandra"],
  },
  {
    canonicalId: "dynamodb",
    name: "Amazon DynamoDB",
    category: "db",
    relatedGroupId: "nosql-db",
    aliases: ["dynamo", "dynamodb", "aws dynamodb"],
  },
  {
    canonicalId: "elasticsearch",
    name: "Elasticsearch",
    category: "db",
    relatedGroupId: "search-db",
    aliases: ["elastic", "elasticsearch", "elastic search", "es"],
  },
  {
    canonicalId: "neo4j",
    name: "Neo4j",
    category: "db",
    relatedGroupId: "graph-db",
    aliases: ["neo4j", "graph database"],
  },
  {
    canonicalId: "couchbase",
    name: "Couchbase",
    category: "db",
    relatedGroupId: "nosql-db",
    aliases: ["couchbase"],
  },
  {
    canonicalId: "bigquery",
    name: "Google Cloud BigQuery",
    category: "db",
    relatedGroupId: "data-warehouse",
    aliases: ["bigquery", "big query", "google bigquery", "bq"],
  },
  {
    canonicalId: "snowflake",
    name: "Snowflake",
    category: "db",
    relatedGroupId: "data-warehouse",
    aliases: ["snowflake", "snowflake db", "snowflake dwh"],
  },
  {
    canonicalId: "redshift",
    name: "Amazon Redshift",
    category: "db",
    relatedGroupId: "data-warehouse",
    aliases: ["redshift", "aws redshift"],
  },
  {
    canonicalId: "clickhouse",
    name: "ClickHouse",
    category: "db",
    relatedGroupId: "columnar-db",
    aliases: ["clickhouse", "click house"],
  },
  {
    canonicalId: "cockroachdb",
    name: "CockroachDB",
    category: "db",
    relatedGroupId: "sql-db",
    aliases: ["cockroachdb", "cockroach db"],
  },
  {
    canonicalId: "timescaledb",
    name: "TimescaleDB",
    category: "db",
    relatedGroupId: "time-series-db",
    aliases: ["timescale", "timescaledb"],
  },
  {
    canonicalId: "influxdb",
    name: "InfluxDB",
    category: "db",
    relatedGroupId: "time-series-db",
    aliases: ["influxdb", "influx db"],
  },
  {
    canonicalId: "couchdb",
    name: "Apache CouchDB",
    category: "db",
    relatedGroupId: "nosql-db",
    aliases: ["couchdb", "couch db"],
  },
  {
    canonicalId: "supabase",
    name: "Supabase",
    category: "db",
    relatedGroupId: "baas-db",
    aliases: ["supabase"],
  },
  {
    canonicalId: "prisma",
    name: "Prisma",
    category: "db",
    relatedGroupId: "orm-tool",
    aliases: ["prisma", "prisma orm"],
  },

  // ── Cloud & Infrastructure (25) ─────────────────────────────────────────────
  {
    canonicalId: "gcp",
    name: "Google Cloud Platform",
    category: "cloud",
    relatedGroupId: "cloud-provider",
    aliases: ["gcp", "google cloud", "google cloud platform"],
  },
  {
    canonicalId: "aws",
    name: "Amazon Web Services",
    category: "cloud",
    relatedGroupId: "cloud-provider",
    aliases: ["aws", "amazon web services", "amazon cloud"],
  },
  {
    canonicalId: "azure",
    name: "Microsoft Azure",
    category: "cloud",
    relatedGroupId: "cloud-provider",
    aliases: ["azure", "microsoft azure", "ms azure"],
  },
  {
    canonicalId: "firebase",
    name: "Firebase",
    category: "cloud",
    relatedGroupId: "baas-platform",
    aliases: ["firebase", "google firebase"],
  },
  {
    canonicalId: "docker",
    name: "Docker",
    category: "cloud",
    relatedGroupId: "container-infra",
    aliases: ["docker", "docker containers", "docker compose"],
  },
  {
    canonicalId: "kubernetes",
    name: "Kubernetes",
    category: "cloud",
    relatedGroupId: "container-orchestration",
    aliases: ["k8s", "kubernetes", "kube"],
  },
  {
    canonicalId: "terraform",
    name: "Terraform",
    category: "cloud",
    relatedGroupId: "iac-tools",
    aliases: ["terraform", "hashicorp terraform", "tf"],
  },
  {
    canonicalId: "ansible",
    name: "Ansible",
    category: "cloud",
    relatedGroupId: "iac-tools",
    aliases: ["ansible", "red hat ansible"],
  },
  {
    canonicalId: "pulumi",
    name: "Pulumi",
    category: "cloud",
    relatedGroupId: "iac-tools",
    aliases: ["pulumi"],
  },
  {
    canonicalId: "cloudformation",
    name: "AWS CloudFormation",
    category: "cloud",
    relatedGroupId: "iac-tools",
    aliases: ["cloudformation", "cloud formation", "cfn"],
  },
  {
    canonicalId: "helm",
    name: "Helm",
    category: "cloud",
    relatedGroupId: "container-orchestration",
    aliases: ["helm", "helm charts"],
  },
  {
    canonicalId: "cloudflare",
    name: "Cloudflare",
    category: "cloud",
    relatedGroupId: "edge-cdn",
    aliases: ["cloudflare", "cloudflare workers"],
  },
  {
    canonicalId: "linux",
    name: "Linux",
    category: "cloud",
    relatedGroupId: "os-infra",
    aliases: ["linux", "ubuntu", "debian", "centos", "redhat", "rhel"],
  },
  {
    canonicalId: "nginx",
    name: "Nginx",
    category: "cloud",
    relatedGroupId: "web-server",
    aliases: ["nginx", "engine x"],
  },
  {
    canonicalId: "apache-http",
    name: "Apache HTTP Server",
    category: "cloud",
    relatedGroupId: "web-server",
    aliases: ["apache", "httpd", "apache server"],
  },
  {
    canonicalId: "ci-cd",
    name: "CI/CD",
    category: "cloud",
    relatedGroupId: "devops-practices",
    aliases: ["ci/cd", "cicd", "continuous integration", "continuous deployment"],
  },
  {
    canonicalId: "github-actions",
    name: "GitHub Actions",
    category: "cloud",
    relatedGroupId: "ci-cd-platform",
    aliases: ["github actions", "gha"],
  },
  {
    canonicalId: "gitlab-ci",
    name: "GitLab CI",
    category: "cloud",
    relatedGroupId: "ci-cd-platform",
    aliases: ["gitlab ci", "gitlab cicd", "gitlab ci/cd"],
  },
  {
    canonicalId: "jenkins",
    name: "Jenkins",
    category: "cloud",
    relatedGroupId: "ci-cd-platform",
    aliases: ["jenkins", "jenkins ci"],
  },
  {
    canonicalId: "circleci",
    name: "CircleCI",
    category: "cloud",
    relatedGroupId: "ci-cd-platform",
    aliases: ["circleci", "circle ci"],
  },
  {
    canonicalId: "argocd",
    name: "Argo CD",
    category: "cloud",
    relatedGroupId: "gitops",
    aliases: ["argocd", "argo cd", "argo"],
  },
  {
    canonicalId: "serverless",
    name: "Serverless",
    category: "cloud",
    relatedGroupId: "cloud-architecture",
    aliases: ["serverless", "cloud functions", "aws lambda"],
  },
  {
    canonicalId: "vercel",
    name: "Vercel",
    category: "cloud",
    relatedGroupId: "edge-cdn",
    aliases: ["vercel"],
  },
  {
    canonicalId: "netlify",
    name: "Netlify",
    category: "cloud",
    relatedGroupId: "edge-cdn",
    aliases: ["netlify"],
  },
  {
    canonicalId: "prometheus",
    name: "Prometheus",
    category: "cloud",
    relatedGroupId: "monitoring",
    aliases: ["prometheus", "prom"],
  },

  // ── Tools & DevOps (25) ─────────────────────────────────────────────────────
  {
    canonicalId: "git",
    name: "Git",
    category: "tool",
    relatedGroupId: "vcs",
    aliases: ["git", "version control"],
  },
  {
    canonicalId: "github",
    name: "GitHub",
    category: "tool",
    relatedGroupId: "vcs-platform",
    aliases: ["github"],
  },
  {
    canonicalId: "gitlab",
    name: "GitLab",
    category: "tool",
    relatedGroupId: "vcs-platform",
    aliases: ["gitlab"],
  },
  {
    canonicalId: "bitbucket",
    name: "Bitbucket",
    category: "tool",
    relatedGroupId: "vcs-platform",
    aliases: ["bitbucket"],
  },
  {
    canonicalId: "grafana",
    name: "Grafana",
    category: "tool",
    relatedGroupId: "monitoring",
    aliases: ["grafana"],
  },
  {
    canonicalId: "datadog",
    name: "Datadog",
    category: "tool",
    relatedGroupId: "monitoring",
    aliases: ["datadog", "data dog"],
  },
  {
    canonicalId: "sentry",
    name: "Sentry",
    category: "tool",
    relatedGroupId: "monitoring",
    aliases: ["sentry", "sentry.io"],
  },
  {
    canonicalId: "splunk",
    name: "Splunk",
    category: "tool",
    relatedGroupId: "monitoring",
    aliases: ["splunk"],
  },
  {
    canonicalId: "jira",
    name: "Jira",
    category: "tool",
    relatedGroupId: "project-tracking",
    aliases: ["jira", "atlassian jira"],
  },
  {
    canonicalId: "confluence",
    name: "Confluence",
    category: "tool",
    relatedGroupId: "project-tracking",
    aliases: ["confluence"],
  },
  {
    canonicalId: "postman",
    name: "Postman",
    category: "tool",
    relatedGroupId: "api-testing",
    aliases: ["postman", "postman api"],
  },
  {
    canonicalId: "swagger",
    name: "Swagger / OpenAPI",
    category: "tool",
    relatedGroupId: "api-testing",
    aliases: ["swagger", "openapi", "open api"],
  },
  {
    canonicalId: "figma",
    name: "Figma",
    category: "tool",
    relatedGroupId: "ui-ux-design",
    aliases: ["figma", "figma design"],
  },
  {
    canonicalId: "vite",
    name: "Vite",
    category: "tool",
    relatedGroupId: "build-tool",
    aliases: ["vite", "vitejs"],
  },
  {
    canonicalId: "webpack",
    name: "Webpack",
    category: "tool",
    relatedGroupId: "build-tool",
    aliases: ["webpack"],
  },
  {
    canonicalId: "npm",
    name: "npm",
    category: "tool",
    relatedGroupId: "pkg-manager",
    aliases: ["npm", "node package manager"],
  },
  {
    canonicalId: "pnpm",
    name: "pnpm",
    category: "tool",
    relatedGroupId: "pkg-manager",
    aliases: ["pnpm"],
  },
  {
    canonicalId: "yarn",
    name: "Yarn",
    category: "tool",
    relatedGroupId: "pkg-manager",
    aliases: ["yarn"],
  },
  {
    canonicalId: "vscode",
    name: "VS Code",
    category: "tool",
    relatedGroupId: "ide-tools",
    aliases: ["vs code", "vscode", "visual studio code"],
  },
  {
    canonicalId: "android-studio",
    name: "Android Studio",
    category: "tool",
    relatedGroupId: "ide-tools",
    aliases: ["android studio"],
  },
  {
    canonicalId: "xcode",
    name: "Xcode",
    category: "tool",
    relatedGroupId: "ide-tools",
    aliases: ["xcode"],
  },
  {
    canonicalId: "intellij",
    name: "IntelliJ IDEA",
    category: "tool",
    relatedGroupId: "ide-tools",
    aliases: ["intellij", "intellij idea"],
  },
  {
    canonicalId: "sonarqube",
    name: "SonarQube",
    category: "tool",
    relatedGroupId: "code-quality",
    aliases: ["sonar", "sonarqube", "sonarcloud"],
  },
  {
    canonicalId: "k6",
    name: "k6",
    category: "tool",
    relatedGroupId: "load-testing",
    aliases: ["k6", "grafana k6"],
  },
  {
    canonicalId: "jmeter",
    name: "Apache JMeter",
    category: "tool",
    relatedGroupId: "load-testing",
    aliases: ["jmeter", "apache jmeter"],
  },

  // ── Soft Skills & Methodologies (25) ────────────────────────────────────────
  {
    canonicalId: "agile",
    name: "Agile",
    category: "soft",
    relatedGroupId: "development-methodology",
    aliases: ["agile", "agile methodology", "agile development"],
  },
  {
    canonicalId: "scrum",
    name: "Scrum",
    category: "soft",
    relatedGroupId: "development-methodology",
    aliases: ["scrum", "scrum master", "sprint planning"],
  },
  {
    canonicalId: "kanban",
    name: "Kanban",
    category: "soft",
    relatedGroupId: "development-methodology",
    aliases: ["kanban", "kanban board"],
  },
  {
    canonicalId: "leadership",
    name: "Leadership",
    category: "soft",
    relatedGroupId: "management-skills",
    aliases: ["leadership", "team leadership", "technical leadership", "tech lead"],
  },
  {
    canonicalId: "mentoring",
    name: "Mentoring",
    category: "soft",
    relatedGroupId: "management-skills",
    aliases: ["mentoring", "coaching", "people management"],
  },
  {
    canonicalId: "communication",
    name: "Communication",
    category: "soft",
    relatedGroupId: "interpersonal-skills",
    aliases: ["communication", "verbal communication", "written communication"],
  },
  {
    canonicalId: "problem-solving",
    name: "Problem Solving",
    category: "soft",
    relatedGroupId: "analytical-skills",
    aliases: ["problem solving", "critical thinking", "analytical skills"],
  },
  {
    canonicalId: "team-collaboration",
    name: "Team Collaboration",
    category: "soft",
    relatedGroupId: "interpersonal-skills",
    aliases: ["collaboration", "teamwork", "team player", "cross-functional collaboration"],
  },
  {
    canonicalId: "code-review",
    name: "Code Review",
    category: "soft",
    relatedGroupId: "engineering-practices",
    aliases: ["code review", "code reviews", "peer review"],
  },
  {
    canonicalId: "system-design",
    name: "System Design",
    category: "soft",
    relatedGroupId: "architecture-skills",
    aliases: ["system design", "software architecture", "distributed systems design"],
  },
  {
    canonicalId: "data-structures",
    name: "Data Structures & Algorithms",
    category: "soft",
    relatedGroupId: "cs-fundamentals",
    aliases: ["dsa", "data structures", "algorithms", "data structures and algorithms"],
  },
  {
    canonicalId: "time-management",
    name: "Time Management",
    category: "soft",
    relatedGroupId: "work-practices",
    aliases: ["time management", "prioritization", "task management"],
  },
  {
    canonicalId: "technical-writing",
    name: "Technical Writing",
    category: "soft",
    relatedGroupId: "documentation-skills",
    aliases: ["technical writing", "documentation", "rfc", "design docs"],
  },
  {
    canonicalId: "conflict-resolution",
    name: "Conflict Resolution",
    category: "soft",
    relatedGroupId: "interpersonal-skills",
    aliases: ["conflict resolution", "negotiation"],
  },
  {
    canonicalId: "stakeholder-management",
    name: "Stakeholder Management",
    category: "soft",
    relatedGroupId: "management-skills",
    aliases: ["stakeholder management", "client facing", "stakeholder communication"],
  },
  {
    canonicalId: "product-management",
    name: "Product Management",
    category: "soft",
    relatedGroupId: "product-strategy",
    aliases: ["product management", "product strategy", "roadmap planning"],
  },
  {
    canonicalId: "presentation",
    name: "Presentation Skills",
    category: "soft",
    relatedGroupId: "interpersonal-skills",
    aliases: ["presentation", "public speaking", "demo presentation"],
  },
  {
    canonicalId: "financial-analysis",
    name: "Financial Analysis",
    category: "soft",
    relatedGroupId: "finance-domain",
    aliases: ["financial analysis", "financial modeling", "budgeting", "forecasting"],
  },
  {
    canonicalId: "sales-strategy",
    name: "Sales Strategy",
    category: "soft",
    relatedGroupId: "sales-domain",
    aliases: ["sales", "b2b sales", "enterprise sales", "closing deals"],
  },
  {
    canonicalId: "marketing-strategy",
    name: "Marketing Strategy",
    category: "soft",
    relatedGroupId: "marketing-domain",
    aliases: ["marketing", "digital marketing", "seo", "content marketing"],
  },
  {
    canonicalId: "customer-success",
    name: "Customer Success",
    category: "soft",
    relatedGroupId: "customer-relations",
    aliases: ["customer success", "client retention", "customer service"],
  },
  {
    canonicalId: "talent-acquisition",
    name: "Talent Acquisition",
    category: "soft",
    relatedGroupId: "hr-domain",
    aliases: ["recruiting", "talent acquisition", "sourcing", "technical recruiting"],
  },
  {
    canonicalId: "operations-management",
    name: "Operations Management",
    category: "soft",
    relatedGroupId: "operations-domain",
    aliases: ["operations", "process improvement", "operational excellence"],
  },
  {
    canonicalId: "risk-management",
    name: "Risk Management",
    category: "soft",
    relatedGroupId: "business-governance",
    aliases: ["risk management", "compliance", "regulatory compliance"],
  },
  {
    canonicalId: "vendor-management",
    name: "Vendor Management",
    category: "soft",
    relatedGroupId: "business-governance",
    aliases: ["vendor management", "procurement", "contract negotiation"],
  },
];

// ── Fast Lookup Map ──────────────────────────────────────────────────────────

const ALIAS_LOOKUP = new Map<string, string>();

for (const entry of SKILLS_DICTIONARY) {
  // Add canonical ID normalized
  ALIAS_LOOKUP.set(entry.canonicalId.toLowerCase(), entry.canonicalId);
  // Add canonical Name normalized
  ALIAS_LOOKUP.set(entry.name.toLowerCase(), entry.canonicalId);
  // Add all aliases normalized
  for (const alias of entry.aliases) {
    const cleaned = alias.toLowerCase().trim().replace(/\s+/g, " ");
    ALIAS_LOOKUP.set(cleaned, entry.canonicalId);

    // Also index without punctuation/dots (e.g. "next.js" -> "nextjs")
    const stripped = cleaned.replace(/[.\-_]/g, "");
    if (!ALIAS_LOOKUP.has(stripped)) {
      ALIAS_LOOKUP.set(stripped, entry.canonicalId);
    }
  }
}

// ── Normalization Function ───────────────────────────────────────────────────

export interface NormalisedSkillResult {
  canonicalId: string | null;
  flagged: boolean;
}

/**
 * Normalises an input skill string to its canonical skill ID.
 *
 * Examples:
 *   "JS"            -> { canonicalId: "javascript", flagged: false }
 *   "javascript"    -> { canonicalId: "javascript", flagged: false }
 *   "Java  Script"  -> { canonicalId: "javascript", flagged: false }
 *   "UnknownTool99" -> { canonicalId: null, flagged: true }
 *   ""              -> { canonicalId: null, flagged: false }
 */
export function normaliseSkill(raw?: string | null): NormalisedSkillResult {
  if (!raw) {
    return { canonicalId: null, flagged: false };
  }

  const cleaned = raw.trim().toLowerCase().replace(/\s+/g, " ");
  if (cleaned.length === 0) {
    return { canonicalId: null, flagged: false };
  }

  // 1. Direct alias match
  const matched = ALIAS_LOOKUP.get(cleaned);
  if (matched) {
    return { canonicalId: matched, flagged: false };
  }

  // 2. Try match without punctuation (e.g. "node.js" -> "nodejs", "c++" -> "cpp")
  const stripped = cleaned.replace(/[.\-_]/g, "");
  const strippedMatch = ALIAS_LOOKUP.get(stripped);
  if (strippedMatch) {
    return { canonicalId: strippedMatch, flagged: false };
  }

  // 3. Skill not recognized in dictionary -> flag for review
  return { canonicalId: null, flagged: true };
}
