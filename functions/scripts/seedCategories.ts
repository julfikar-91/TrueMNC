// functions/scripts/seedCategories.ts
import type * as admin from "firebase-admin";
import { initializeScriptAdmin } from "./envGuard";

export interface CategorySeedData {
  id: string;
  name: string;
  type: "TECHNICAL" | "NON_TECHNICAL";
  aliases: string[];
  keywords: string[];
  order: number;
  active: boolean;
  activeCount: number;
}

export const CATEGORIES_SEED: CategorySeedData[] = [
  // ── Technical Categories (1-10) ───────────────────────────────────────────
  {
    id: "software-development",
    name: "Software Development",
    type: "TECHNICAL",
    aliases: ["Software Engineering", "Application Development", "Programming", "Coding", "App Dev"],
    keywords: ["flutter", "react", "python", "java", "typescript", "golang", "c++", "c#", "mobile", "full stack", "backend", "frontend"],
    order: 1,
    active: true,
    activeCount: 0,
  },
  {
    id: "data-science",
    name: "Data Science",
    type: "TECHNICAL",
    aliases: ["Data Analytics", "Big Data", "Data Engineering", "BI", "Business Intelligence"],
    keywords: ["python", "r", "pandas", "numpy", "spark", "sql", "tableau", "power bi", "etl", "data warehouse"],
    order: 2,
    active: true,
    activeCount: 0,
  },
  {
    id: "ai-ml",
    name: "AI/ML",
    type: "TECHNICAL",
    aliases: ["Artificial Intelligence", "Machine Learning", "Deep Learning", "GenAI", "NLP"],
    keywords: ["pytorch", "tensorflow", "keras", "scikit-learn", "llm", "gemini", "neural networks", "computer vision", "nlp"],
    order: 3,
    active: true,
    activeCount: 0,
  },
  {
    id: "cyber-security",
    name: "Cyber Security",
    type: "TECHNICAL",
    aliases: ["Information Security", "InfoSec", "Application Security", "AppSec", "Network Security"],
    keywords: ["security", "penetration testing", "soc", "siem", "compliance", "firewall", "vulnerability assessment", "cryptography"],
    order: 4,
    active: true,
    activeCount: 0,
  },
  {
    id: "cloud",
    name: "Cloud",
    type: "TECHNICAL",
    aliases: ["Cloud Computing", "Cloud Architecture", "Cloud Engineering", "Cloud Infrastructure"],
    keywords: ["gcp", "aws", "azure", "google cloud", "amazon web services", "cloud architect", "serverless", "cloud storage"],
    order: 5,
    active: true,
    activeCount: 0,
  },
  {
    id: "devops",
    name: "DevOps",
    type: "TECHNICAL",
    aliases: ["SRE", "Site Reliability Engineering", "Infrastructure Engineering", "Platform Engineering"],
    keywords: ["docker", "kubernetes", "k8s", "terraform", "ansible", "ci/cd", "jenkins", "github actions", "helm", "linux"],
    order: 6,
    active: true,
    activeCount: 0,
  },
  {
    id: "testing",
    name: "Testing",
    type: "TECHNICAL",
    aliases: ["QA", "Quality Assurance", "Test Automation", "Software Testing", "SDET"],
    keywords: ["automation testing", "selenium", "cypress", "playwright", "junit", "performance testing", "jmeter", "manual testing"],
    order: 7,
    active: true,
    activeCount: 0,
  },
  {
    id: "ui-ux",
    name: "UI/UX",
    type: "TECHNICAL",
    aliases: ["Product Design", "User Experience", "User Interface Design", "Interaction Design"],
    keywords: ["figma", "sketch", "adobe xd", "wireframing", "prototyping", "design systems", "user research", "usability testing"],
    order: 8,
    active: true,
    activeCount: 0,
  },
  {
    id: "database",
    name: "Database",
    type: "TECHNICAL",
    aliases: ["Database Administration", "DBA", "Database Engineering", "Data Storage"],
    keywords: ["postgresql", "mysql", "mongodb", "firestore", "redis", "oracle", "sql server", "dynamodb", "indexing", "sharding"],
    order: 9,
    active: true,
    activeCount: 0,
  },
  {
    id: "networking",
    name: "Networking",
    type: "TECHNICAL",
    aliases: ["Network Engineering", "Network Administration", "Infrastructure Networking"],
    keywords: ["tcp/ip", "dns", "vpn", "cisco", "routing", "switching", "load balancing", "lan", "wan", "bgp"],
    order: 10,
    active: true,
    activeCount: 0,
  },

  // ── Non-Technical Categories (11-20) ──────────────────────────────────────
  {
    id: "hr",
    name: "HR",
    type: "NON_TECHNICAL",
    aliases: ["Human Resources", "People Operations", "Talent Acquisition", "Recruiting"],
    keywords: ["recruiting", "talent acquisition", "employee engagement", "payroll", "onboarding", "hr policies", "sourcing"],
    order: 11,
    active: true,
    activeCount: 0,
  },
  {
    id: "finance",
    name: "Finance",
    type: "NON_TECHNICAL",
    aliases: ["Accounting", "Financial Planning", "FP&A", "Treasury", "Auditing"],
    keywords: ["financial modeling", "budgeting", "p&l", "taxation", "auditing", "cash flow", "financial reporting", "cpa"],
    order: 12,
    active: true,
    activeCount: 0,
  },
  {
    id: "marketing",
    name: "Marketing",
    type: "NON_TECHNICAL",
    aliases: ["Digital Marketing", "Growth Marketing", "Brand Marketing", "Content Marketing"],
    keywords: ["seo", "sem", "content marketing", "social media", "campaigns", "email marketing", "analytics", "growth"],
    order: 13,
    active: true,
    activeCount: 0,
  },
  {
    id: "sales",
    name: "Sales",
    type: "NON_TECHNICAL",
    aliases: ["Account Executive", "Inside Sales", "Direct Sales", "Enterprise Sales"],
    keywords: ["b2b sales", "cold outreach", "prospecting", "quota", "lead generation", "crm", "salesforce", "closing"],
    order: 14,
    active: true,
    activeCount: 0,
  },
  {
    id: "business-development",
    name: "Business Development",
    type: "NON_TECHNICAL",
    aliases: ["BizDev", "Strategic Partnerships", "Corporate Development", "Alliances"],
    keywords: ["partnerships", "b2b", "market expansion", "contract negotiation", "strategic alliances", "networking"],
    order: 15,
    active: true,
    activeCount: 0,
  },
  {
    id: "operations",
    name: "Operations",
    type: "NON_TECHNICAL",
    aliases: ["Business Operations", "BizOps", "Supply Chain", "Logistics", "Operational Excellence"],
    keywords: ["process improvement", "supply chain", "logistics", "vendor management", "procurement", "efficiency", "sla"],
    order: 16,
    active: true,
    activeCount: 0,
  },
  {
    id: "administration",
    name: "Administration",
    type: "NON_TECHNICAL",
    aliases: ["Office Administration", "Executive Assistant", "Facilities", "Admin Support"],
    keywords: ["office management", "scheduling", "facility management", "records management", "executive support"],
    order: 17,
    active: true,
    activeCount: 0,
  },
  {
    id: "customer-support",
    name: "Customer Support",
    type: "NON_TECHNICAL",
    aliases: ["Customer Service", "Customer Care", "Helpdesk", "Client Support"],
    keywords: ["ticketing", "zendesk", "freshdesk", "customer satisfaction", "csat", "problem resolution", "troubleshooting"],
    order: 18,
    active: true,
    activeCount: 0,
  },
  {
    id: "business-analysis",
    name: "Business Analysis",
    type: "NON_TECHNICAL",
    aliases: ["Business Analyst", "Functional Analyst", "Requirements Engineering"],
    keywords: ["brd", "frd", "user stories", "gap analysis", "process modeling", "stakeholder interviews", "scrum"],
    order: 19,
    active: true,
    activeCount: 0,
  },
  {
    id: "management",
    name: "Management",
    type: "NON_TECHNICAL",
    aliases: ["General Management", "Program Management", "Project Management", "Executive Leadership"],
    keywords: ["leadership", "pmp", "resource management", "strategic planning", "stakeholder management", "budget management"],
    order: 20,
    active: true,
    activeCount: 0,
  },
];

export async function seedCategories(db?: admin.firestore.Firestore): Promise<{ total: number }> {
  const adminSdk = (await import("firebase-admin")) as unknown as typeof admin;
  const firestore = db || (await initializeScriptAdmin());
  const col = firestore.collection("categories");
  const batch = firestore.batch();

  console.log(`[CATEGORIES-SEED] Preparing batch write for ${CATEGORIES_SEED.length} categories...`);

  for (const cat of CATEGORIES_SEED) {
    const docRef = col.doc(cat.id);
    batch.set(
      docRef,
      {
        name: cat.name,
        type: cat.type,
        aliases: cat.aliases,
        keywords: cat.keywords,
        order: cat.order,
        active: cat.active,
        activeCount: cat.activeCount,
        updatedAt: adminSdk.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  await batch.commit();
  console.log(`[CATEGORIES-SEED] ✅ Successfully seeded ${CATEGORIES_SEED.length} categories.`);
  return { total: CATEGORIES_SEED.length };
}
