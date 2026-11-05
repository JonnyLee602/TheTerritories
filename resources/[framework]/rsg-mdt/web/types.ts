export interface Officer {
  name: string;
  citizenid: string;
  job: { name: string; label: string; grade: { name: string } };
  isLaw: boolean;
}

export interface Citizen {
  citizenid: string;
  charinfo: { firstname: string; lastname: string; gender: number; birthdate: string };
  job: { name: string; label: string; grade: { name: string } };
  money?: { cash: number; bank: number; bloodmoney: number };
  metadata?: { [key: string]: any };
  profilePicture?: string | null;
  isWanted?: boolean;
  records?: CriminalRecord[];
  fines?: Fine[];
  playerId?: number;
}

export interface CriminalRecord {
  id: number;
  citizenid: string;
  name: string;
  crime: string;
  description: string;
  fine: number;
  jailtime: number;
  officer: string;
  date: string;
}

export interface Warrant {
  id: number;
  citizenid: string;
  name: string;
  reason: string;
  status: 'active' | 'served' | 'expired';
  officer: string;
  created_at: string;
}

export interface BOLO {
  id: number;
  title: string;
  description: string;
  lastSeen: string;
  officer: string;
  date: string;
}

export interface LinkedCharge {
  charge_id: number;
  charge_name: string;
  citizen_name: string;
  fine: number;
  jailtime: number;
  officer: string;
}

export interface Report {
  id: number;
  title: string;
  type: string;
  description: string;
  officers: string[];
  suspects: string[];
  evidence: string[];
  officer: string;
  officer_cid?: string;
  created_at: string;
  linkedCharge?: LinkedCharge;
}

export interface ReportComment {
  id: number;
  report_id: number;
  author: string;
  author_cid?: string;
  content: string;
  created_at: string;
}

export interface Stats {
  records: number;
  activeWarrants: number;
  activeBolos: number;
  reports: number;
  unpaidFines?: number;
}

export interface IncidentType {
  value: string;
  label: string;
  color: string;
}

export interface StaffPermissions {
  canCreateRecords?: boolean;
  canDeleteRecords?: boolean;
  canManageWarrants?: boolean;
  isAdmin?: boolean;
}

export interface StaffMember {
  id: number;
  citizenid: string;
  name: string;
  role: string;
  role_label?: string;
  permissions: StaffPermissions;
  department?: string;
  created_at: string;
  updated_at: string;
}

export interface Role {
  id: number;
  name: string;
  label: string;
  permissions: StaffPermissions;
  created_at: string;
}

export interface ConfigRoleGrade {
  level: number;
  label: string;
  permissions: StaffPermissions;
}

export interface ConfigRole {
  name: string;
  label: string;
  grades: ConfigRoleGrade[];
  isConfigRole: boolean;
}

export interface AuditLog {
  id: number;
  action: string;
  target_type: string;
  target_id: string;
  target_name: string;
  details: string | null;
  performed_by: string;
  performed_by_name: string;
  created_at: string;
}

export interface LawJob {
  name: string;
  label: string;
}

export interface JobGrade {
  level: number;
  label: string;
  isAdmin: boolean;
}

export interface PlayerForJob {
  citizenid: string;
  charinfo: { firstname: string; lastname: string };
  job: { name: string; label: string };
  hasLawJob: boolean;
  lawJobName?: string;
}

export interface OfficerForManagement {
  citizenid: string;
  name: string;
  role: string;
  role_label?: string;
  jobName?: string;
  jobLabel?: string;
  gradeLevel?: number;
  gradeLabel?: string;
  isLaw: boolean;
}

export interface JobPlayerCount {
  name: string;
  label: string;
  count: number;
}

export interface SyncResult {
  success: boolean;
  message: string;
  added: number;
  players?: { citizenid: string; name: string; job: string }[];
}

export interface ChargeTemplate {
  id: number;
  name: string;
  description: string | null;
  fine: number;
  jailtime: number;
  category: string;
  created_by: string | null;
  created_by_name: string | null;
  created_at: string;
  updated_at: string;
}

export interface IssuedCharge {
  id: number;
  citizenid: string;
  citizen_name: string;
  charge_template_id: number | null;
  charge_name: string;
  charge_description: string | null;
  fine: number;
  jailtime: number;
  time_served?: number;
  is_served?: boolean;
  officer: string;
  officer_cid: string | null;
  report_id: number | null;
  created_at: string;
  served_at?: string | null;
  category?: string;
  fine_id?: number | null;
  due_date?: string | null;
  fine_status?: 'unpaid' | 'paid' | 'overdue' | null;
  paid_at?: string | null;
}

export interface JailTotals {
  totalJailtime: number;
  totalServed: number;
  outstanding: number;
  charges: {
    id: number;
    charge_name: string;
    jailtime: number;
    time_served: number;
    is_served: boolean;
    created_at: string;
  }[];
}

export interface ChargeFormData {
  name: string;
  description: string;
  fine: number;
  jailtime: number;
  category: string;
}

export interface IssueChargesData {
  citizenid: string;
  charges: {
    templateId?: number;
    name: string;
    description?: string;
    fine: number;
    jailtime: number;
  }[];
  reportId?: number;
}

export interface ChargeCategory {
  value: string;
  label: string;
  color: string;
}

export interface Fine {
  id: number;
  citizenid: string;
  citizen_name: string;
  issued_charge_ids: number[];
  total_amount: number;
  due_date: string;
  status: 'unpaid' | 'paid' | 'overdue';
  issued_at: string;
  paid_at: string | null;
  officer_name: string;
  officer_cid: string | null;
  paid_to_officer: string | null;
}

export interface ReportForAttachment {
  id: number;
  title: string;
  type: string;
  officer: string;
  created_at: string;
}

export interface ChargeAttachment {
  attachment_id: number;
  charge_id: number;
  report_id: number;
  attached_by: string;
  attached_by_name: string;
  attached_at: string;
  report_title: string;
  report_type: string;
  report_officer: string;
  report_created_at: string;
}

export interface AttachReportsResult {
  success: boolean;
  message: string;
  attachedCount?: number;
  alreadyAttached?: number;
  notFound?: number;
}

export interface JailConfig {
  delaySeconds: number;
  maxDistance: number;
  jailCoords: { x: number; y: number; z: number };
  jailHeading: number;
  enabled: boolean;
  minutesPerMonth: number;
  maxJailDistance: number;
}

export interface JailStatus {
  status: 'idle' | 'processing' | 'completed' | 'cancelled' | 'failed';
  remaining?: number;
  message?: string;
  jailed?: boolean;
  totalJailtime?: number;
  totalServed?: number;
  citizenName?: string;
}
