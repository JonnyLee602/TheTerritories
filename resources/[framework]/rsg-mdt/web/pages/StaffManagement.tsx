import { useState, useEffect, useMemo } from 'react';
import { fetchNui, useNuiEvent } from '../hooks/useNui';
import type { StaffMember, ConfigRole, AuditLog, StaffPermissions, Citizen, LawJob, OfficerForManagement, JobPlayerCount, SyncResult } from '../types';
import { ConfirmModal } from '../components/ConfirmModal';
import { JobAssignment } from '../components/JobAssignment';
import { OfficerDetailModal } from '../components/OfficerDetailModal';
import { AdminChargesManager } from '../components/AdminChargesManager';

type Tab = 'staff' | 'officers' | 'roles' | 'logs' | 'jobs' | 'charges';

export function StaffManagement() {
  const [activeTab, setActiveTab] = useState<Tab>('staff');
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [officers, setOfficers] = useState<OfficerForManagement[]>([]);
  const [configRoles, setConfigRoles] = useState<ConfigRole[]>([]);
  const [auditLogs, setAuditLogs] = useState<AuditLog[]>([]);
  const [lawJobs, setLawJobs] = useState<LawJob[]>([]);
  const [jobCounts, setJobCounts] = useState<JobPlayerCount[]>([]);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [syncMessage, setSyncMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<Citizen[]>([]);
  const [searching, setSearching] = useState(false);
  const [jobFilter, setJobFilter] = useState<string>('all');

  const [showAddModal, setShowAddModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showConfirm, setShowConfirm] = useState<{ type: string; data: any } | null>(null);
  const [selectedOfficer, setSelectedOfficer] = useState<OfficerForManagement | null>(null);

  const [editingStaff, setEditingStaff] = useState<StaffMember | null>(null);
  const [newStaffCitizenid, setNewStaffCitizenid] = useState('');
  const [newStaffRole, setNewStaffRole] = useState('');
  const [newStaffPermissions, setNewStaffPermissions] = useState<StaffPermissions>({});

  useEffect(() => {
    fetchInitialData();
  }, []);

  const fetchInitialData = async () => {
    setLoading(true);
    setError(null);
    try {
      await Promise.all([fetchStaff(), fetchOfficers(), fetchConfigRoles(), fetchLogs(), fetchLawJobs(), fetchJobCounts()]);
      await syncStaff();
    } catch (err) {
      setError('Failed to load staff data');
    }
    setLoading(false);
  };

  const fetchStaff = async () => {
    const result = await fetchNui<StaffMember[]>('getStaff', {}, []);
    setStaff(result);
  };

  const fetchOfficers = async () => {
    const result = await fetchNui<OfficerForManagement[]>('getOfficers', {}, []);
    setOfficers(result);
  };

  const fetchConfigRoles = async () => {
    const result = await fetchNui<ConfigRole[]>('getConfigRoles', {}, []);
    setConfigRoles(result);
  };

  const fetchLogs = async () => {
    const result = await fetchNui<AuditLog[]>('getAuditLogs', {}, []);
    setAuditLogs(result);
  };

  const fetchLawJobs = async () => {
    const result = await fetchNui<LawJob[]>('getLawJobs', {}, []);
    setLawJobs(result);
  };

  const fetchJobCounts = async () => {
    const result = await fetchNui<JobPlayerCount[]>('getJobPlayerCounts', {}, []);
    setJobCounts(result);
  };

  const syncStaff = async (filterJob?: string) => {
    setSyncing(true);
    setSyncMessage(null);
    try {
      const result = await fetchNui<SyncResult>('syncStaffFromJobs', { job: filterJob }, { success: true, message: 'Synced', added: 0 });
      if (result.success && result.added > 0) {
        setSyncMessage(result.message);
        await Promise.all([fetchStaff(), fetchOfficers(), fetchJobCounts()]);
      }
    } catch (err) {
      console.error('Failed to sync staff:', err);
    }
    setSyncing(false);
  };

  const handleRefresh = async () => {
    setLoading(true);
    setError(null);
    try {
      await Promise.all([fetchStaff(), fetchOfficers(), fetchConfigRoles(), fetchLogs(), fetchJobCounts()]);
    } catch (err) {
      setError('Failed to refresh data');
    }
    setLoading(false);
  };

  useNuiEvent('staffUpdated', async () => {
    await Promise.all([fetchStaff(), fetchOfficers(), fetchJobCounts()]);
  });

  useNuiEvent('rolesUpdated', () => {
    fetchConfigRoles();
  });

  useNuiEvent('departmentUpdated', async () => {
    await Promise.all([fetchStaff(), fetchOfficers(), fetchJobCounts()]);
  });

  const handleSearchCitizens = async (query: string) => {
    setSearchQuery(query);
    if (query.length < 2) {
      setSearchResults([]);
      return;
    }
    setSearching(true);
    const results = await fetchNui<Citizen[]>('searchCitizensForStaff', { query }, []);
    setSearchResults(results);
    setSearching(false);
  };

  const handleAddStaff = async () => {
    if (!newStaffCitizenid || !newStaffRole) return;
    const [deptName, gradeLevel] = newStaffRole.split(':');
    const result = await fetchNui<{ success: boolean; message?: string }>('addStaff', {
      citizenid: newStaffCitizenid,
      role: newStaffRole,
      department: deptName,
      gradeLevel: parseInt(gradeLevel),
      permissions: newStaffPermissions,
    }, { success: true });
    if (result.success) {
      setShowAddModal(false);
      setNewStaffCitizenid('');
      setNewStaffRole('');
      setNewStaffPermissions({});
      setSearchQuery('');
      setSearchResults([]);
      fetchStaff();
    }
  };

  const handleRemoveStaff = async (citizenid: string) => {
    const result = await fetchNui<{ success: boolean; message?: string }>('removeStaff', { citizenid }, { success: true });
    if (result.success) {
      fetchStaff();
      fetchLogs();
    }
    setShowConfirm(null);
  };

  const handleUpdateStaff = async () => {
    if (!editingStaff) return;
    const result = await fetchNui<{ success: boolean; message?: string }>('updateStaffPermissions', {
      citizenid: editingStaff.citizenid,
      role: editingStaff.role,
      permissions: editingStaff.permissions,
    }, { success: true });
    if (result.success) {
      setShowEditModal(false);
      setEditingStaff(null);
      fetchStaff();
      fetchLogs();
    }
  };

  const filteredStaff = useMemo(() => {
    let filtered = staff;
    
    if (jobFilter !== 'all') {
      filtered = filtered.filter((s) => {
        if (!s.department) return false;
        const job = lawJobs.find((j) => j.label === s.department);
        return job && job.name === jobFilter;
      });
    }
    
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      filtered = filtered.filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          s.citizenid.toLowerCase().includes(q) ||
          s.role.toLowerCase().includes(q)
      );
    }
    
    return filtered;
  }, [staff, jobFilter, searchQuery, lawJobs]);

  const getActionLabel = (action: string) => {
    const labels: Record<string, string> = {
      staff_added: 'Staff Added',
      staff_removed: 'Staff Removed',
      staff_updated: 'Staff Updated',
      staff_synced: 'Staff Synced',
      role_created: 'Role Created',
      role_updated: 'Role Updated',
      role_deleted: 'Role Deleted',
    };
    return labels[action] || action;
  };

  const getActionColor = (action: string) => {
    if (action.includes('added') || action.includes('created') || action.includes('synced')) return 'text-green-400';
    if (action.includes('removed') || action.includes('deleted')) return 'text-red-400';
    return 'text-amber-400';
  };

  const renderPermissionToggle = (
    _permission: keyof StaffPermissions,
    label: string,
    value: boolean | undefined,
    onChange: (val: boolean) => void
  ) => (
    <label className="flex items-center gap-3 cursor-pointer">
      <input
        type="checkbox"
        checked={value || false}
        onChange={(e) => onChange(e.target.checked)}
        className="w-4 h-4 rounded border-zinc-600 bg-zinc-800 text-amber-600 focus:ring-amber-500"
      />
      <span className="text-sm text-zinc-300">{label}</span>
    </label>
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <div className="animate-spin w-8 h-8 border-2 border-amber-500 border-t-transparent rounded-full mx-auto mb-3" />
          <div className="text-zinc-400">Loading staff data...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white" style={{ fontFamily: 'var(--font-display)' }}>
          Management
        </h2>
        <div className="flex items-center gap-3">
          <button
            onClick={handleRefresh}
            disabled={loading || syncing}
            className="flex items-center gap-2 px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 disabled:opacity-50 rounded-lg text-sm text-zinc-300 transition-colors"
          >
            <svg className={`w-4 h-4 ${syncing ? 'animate-spin' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="bg-red-900/20 border border-red-800 rounded-lg p-4 text-red-400">
          {error}
        </div>
      )}

      {syncMessage && (
        <div className="bg-green-900/20 border border-green-800 rounded-lg p-4 flex items-center justify-between">
          <span className="text-green-400">{syncMessage}</span>
          <button onClick={() => setSyncMessage(null)} className="text-green-400 hover:text-green-300">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      )}

      <div className="flex gap-2 border-b border-zinc-800 pb-2">
        {(['staff', 'officers', 'roles', 'logs', 'jobs', 'charges'] as Tab[]).map((tab) => (
          <button
            key={tab}
            onClick={() => {
              setActiveTab(tab);
              setSearchQuery('');
            }}
            className={`px-4 py-2 text-sm font-medium rounded-t transition-colors ${
              activeTab === tab
                ? 'bg-zinc-800 text-white border-b-2 border-amber-500'
                : 'text-zinc-400 hover:text-white'
            }`}
          >
            {tab === 'staff' ? 'Staff Members' : tab === 'officers' ? 'Officers' : tab === 'roles' ? 'Roles' : tab === 'logs' ? 'Activity Log' : tab === 'jobs' ? 'Job Assignment' : 'Charges'}
          </button>
        ))}
      </div>

      {activeTab === 'staff' && (
        <div className="space-y-4">
          <div className="flex gap-4 items-center">
            <input
              type="text"
              placeholder="Search staff..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="flex-1 bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
            />
            <select
              value={jobFilter}
              onChange={(e) => setJobFilter(e.target.value)}
              className="bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-amber-600"
            >
              <option value="all">All Departments</option>
              {lawJobs.map((job) => (
                <option key={job.name} value={job.name}>
                  {job.label}
                </option>
              ))}
            </select>
            <button
              onClick={() => syncStaff(jobFilter !== 'all' ? jobFilter : undefined)}
              disabled={syncing}
              className="flex items-center gap-2 bg-zinc-700 hover:bg-zinc-600 disabled:opacity-50 px-4 py-2 rounded-lg text-white text-sm font-medium transition-colors"
            >
              {syncing ? (
                <>
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  Syncing...
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  Sync from Jobs
                </>
              )}
            </button>
            <button
              onClick={() => setShowAddModal(true)}
              className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded-lg text-white text-sm font-medium transition-colors"
            >
              Add Staff
            </button>
          </div>

          {jobFilter !== 'all' && (
            <div className="flex items-center gap-4 text-sm">
              {jobCounts.filter((j) => j.name === jobFilter).map((job) => (
                <div key={job.name} className="flex items-center gap-2 text-zinc-400">
                  <span className="font-medium text-white">{job.label}</span>
                  <span className="px-2 py-0.5 bg-blue-900/30 text-blue-400 rounded">
                    {job.count} player{job.count !== 1 ? 's' : ''}
                  </span>
                  <span className="px-2 py-0.5 bg-green-900/30 text-green-400 rounded">
                    {filteredStaff.length} in staff
                  </span>
                </div>
              ))}
            </div>
          )}

          <div className="bg-zinc-900 border border-zinc-800 rounded-lg overflow-hidden">
            <table className="w-full">
              <thead className="bg-zinc-800">
                <tr>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Name</th>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Citizen ID</th>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Department</th>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Role</th>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Permissions</th>
                  <th className="px-4 py-3 text-right text-xs text-zinc-400 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-800">
                {filteredStaff.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-zinc-500">
                      No staff members found
                    </td>
                  </tr>
                ) : (
                  filteredStaff.map((member) => (
                    <tr key={member.id} className="hover:bg-zinc-800/50">
                      <td className="px-4 py-3 text-white">{member.name}</td>
                      <td className="px-4 py-3 text-zinc-400 font-mono text-sm">{member.citizenid}</td>
                      <td className="px-4 py-3">
                        {member.department ? (
                          <span className="px-2 py-1 rounded bg-blue-900/30 text-blue-400 text-xs">
                            {member.department}
                          </span>
                        ) : (
                          <span className="text-zinc-500 text-xs">No department</span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <span className="px-2 py-1 rounded bg-zinc-800 text-amber-400 text-xs">
                          {member.role_label || member.role}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex gap-1 flex-wrap">
                          {member.permissions?.isAdmin && (
                            <span className="px-1.5 py-0.5 rounded bg-red-900/30 text-red-400 text-xs">Admin</span>
                          )}
                          {member.permissions?.canDeleteRecords && (
                            <span className="px-1.5 py-0.5 rounded bg-orange-900/30 text-orange-400 text-xs">Delete</span>
                          )}
                          {member.permissions?.canManageWarrants && (
                            <span className="px-1.5 py-0.5 rounded bg-blue-900/30 text-blue-400 text-xs">Warrants</span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-right">
                        <button
                          onClick={() => {
                            setEditingStaff(member);
                            setShowEditModal(true);
                          }}
                          className="text-amber-400 hover:text-amber-300 text-sm mr-3"
                        >
                          Edit
                        </button>
                        <button
                          onClick={() => setShowConfirm({ type: 'staff', data: member })}
                          className="text-red-400 hover:text-red-300 text-sm"
                        >
                          Remove
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {activeTab === 'officers' && (
        <div className="space-y-4">
          <div className="flex gap-4">
            <input
              type="text"
              placeholder="Search officers..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="flex-1 bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
            />
          </div>

          <div className="bg-zinc-900 border border-zinc-800 rounded-lg overflow-hidden">
            <table className="w-full">
              <thead className="bg-zinc-800">
                <tr>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Name</th>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Citizen ID</th>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Department</th>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Grade</th>
                  <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Status</th>
                  <th className="px-4 py-3 text-right text-xs text-zinc-400 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-800">
                {officers.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-zinc-500">
                      No officers found
                    </td>
                  </tr>
                ) : (
                  officers
                    .filter((o) => {
                      if (!searchQuery) return true;
                      const q = searchQuery.toLowerCase();
                      return o.name.toLowerCase().includes(q) || o.citizenid.toLowerCase().includes(q);
                    })
                    .map((officer) => (
                      <tr key={officer.citizenid} className="hover:bg-zinc-800/50">
                        <td className="px-4 py-3 text-white">{officer.name}</td>
                        <td className="px-4 py-3 text-zinc-400 font-mono text-sm">{officer.citizenid}</td>
                        <td className="px-4 py-3">
                          {officer.isLaw && officer.jobLabel ? (
                            <span className="px-2 py-1 rounded bg-blue-900/30 text-blue-400 text-xs">
                              {officer.jobLabel}
                            </span>
                          ) : (
                            <span className="text-zinc-500 text-xs">No department</span>
                          )}
                        </td>
                        <td className="px-4 py-3">
                          {officer.gradeLabel ? (
                            <span className="text-zinc-300 text-sm">{officer.gradeLabel}</span>
                          ) : (
                            <span className="text-zinc-500 text-xs">-</span>
                          )}
                        </td>
                        <td className="px-4 py-3">
                          {officer.isLaw ? (
                            <span className="px-2 py-1 rounded bg-green-900/30 text-green-400 text-xs">Active</span>
                          ) : (
                            <span className="px-2 py-1 rounded bg-zinc-700 text-zinc-400 text-xs">Inactive</span>
                          )}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <button
                            onClick={() => setSelectedOfficer(officer)}
                            className="text-amber-400 hover:text-amber-300 text-sm"
                          >
                            Manage
                          </button>
                        </td>
                      </tr>
                    ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {activeTab === 'roles' && (
        <div className="space-y-4">
          <div className="bg-blue-900/20 border border-blue-800 rounded-lg p-4 mb-4">
            <div className="flex items-center gap-2 text-blue-400">
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span className="text-sm">Roles and grades are defined in <code className="bg-zinc-800 px-1 rounded">Config.LawJobs</code> in shared/config.lua</span>
            </div>
          </div>

          {configRoles.length === 0 ? (
            <div className="bg-zinc-900 border border-zinc-800 rounded-lg p-8 text-center text-zinc-500">
              No law job roles defined in Config.LawJobs
            </div>
          ) : (
            <div className="grid gap-6">
              {configRoles.map((dept) => (
                <div key={dept.name} className="bg-zinc-900 border border-zinc-800 rounded-lg overflow-hidden">
                  <div className="bg-zinc-800 px-4 py-3 border-b border-zinc-700">
                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-white font-bold text-lg">{dept.label}</h3>
                        <p className="text-zinc-500 text-sm font-mono">{dept.name}</p>
                      </div>
                      <span className="px-2 py-1 rounded bg-blue-900/30 text-blue-400 text-xs">
                        {dept.grades.length} grade{dept.grades.length !== 1 ? 's' : ''}
                      </span>
                    </div>
                  </div>
                  
                  <div className="divide-y divide-zinc-800">
                    {dept.grades.map((grade) => (
                      <div key={grade.level} className="px-4 py-3 flex items-center justify-between">
                        <div className="flex items-center gap-4">
                          <div className="w-10 h-10 rounded-lg bg-zinc-800 flex items-center justify-center">
                            <span className="text-amber-400 font-bold text-sm">{grade.level}</span>
                          </div>
                          <div>
                            <h4 className="text-white font-medium">{grade.label}</h4>
                            <p className="text-zinc-500 text-xs">Grade Level: {grade.level}</p>
                          </div>
                        </div>
                        <div className="flex gap-1.5 flex-wrap justify-end">
                          {grade.permissions.canCreateRecords && (
                            <span className="px-1.5 py-0.5 rounded bg-green-900/30 text-green-400 text-xs">Create Records</span>
                          )}
                          {grade.permissions.canDeleteRecords && (
                            <span className="px-1.5 py-0.5 rounded bg-orange-900/30 text-orange-400 text-xs">Delete Records</span>
                          )}
                          {grade.permissions.canManageWarrants && (
                            <span className="px-1.5 py-0.5 rounded bg-blue-900/30 text-blue-400 text-xs">Manage Warrants</span>
                          )}
                          {grade.permissions.isAdmin && (
                            <span className="px-1.5 py-0.5 rounded bg-red-900/30 text-red-400 text-xs font-medium">Admin</span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {activeTab === 'logs' && (
        <div className="bg-zinc-900 border border-zinc-800 rounded-lg overflow-hidden">
          <div className="max-h-[500px] overflow-y-auto">
            {auditLogs.length === 0 ? (
              <div className="p-8 text-center text-zinc-500">No activity logs found</div>
            ) : (
              <table className="w-full">
                <thead className="bg-zinc-800 sticky top-0">
                  <tr>
                    <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Action</th>
                    <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Target</th>
                    <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Performed By</th>
                    <th className="px-4 py-3 text-left text-xs text-zinc-400 uppercase tracking-wider">Date</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-800">
                  {auditLogs.map((log) => (
                    <tr key={log.id} className="hover:bg-zinc-800/50">
                      <td className="px-4 py-3">
                        <span className={`text-sm font-medium ${getActionColor(log.action)}`}>
                          {getActionLabel(log.action)}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <span className="text-white text-sm">{log.target_name}</span>
                        <span className="text-zinc-500 text-xs ml-2">({log.target_type})</span>
                      </td>
                      <td className="px-4 py-3 text-zinc-300 text-sm">{log.performed_by_name}</td>
                      <td className="px-4 py-3 text-zinc-500 text-sm">
                        {new Date(log.created_at).toLocaleString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}

      {activeTab === 'jobs' && (
        <JobAssignment lawJobs={lawJobs} />
      )}

      {activeTab === 'charges' && (
        <AdminChargesManager />
      )}

      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div className="absolute inset-0 bg-black/70" onClick={() => setShowAddModal(false)} />
          <div className="relative bg-zinc-900 border border-zinc-700 rounded-xl w-full max-w-md p-6">
            <h3 className="text-white text-lg font-bold mb-4">Add Staff Member</h3>

            <div className="space-y-4">
              <div>
                <label className="block text-zinc-400 text-sm mb-1">Search Citizen</label>
                <input
                  type="text"
                  placeholder="Search by name or citizen ID..."
                  value={searchQuery}
                  onChange={(e) => handleSearchCitizens(e.target.value)}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
                />
                {searching && <p className="text-zinc-500 text-xs mt-1">Searching...</p>}
                {searchResults.length > 0 && (
                  <div className="mt-2 max-h-40 overflow-y-auto bg-zinc-800 border border-zinc-700 rounded">
                    {searchResults.map((citizen) => (
                      <button
                        key={citizen.citizenid}
                        onClick={() => {
                          setNewStaffCitizenid(citizen.citizenid);
                          setSearchQuery(`${citizen.charinfo?.firstname} ${citizen.charinfo?.lastname}`);
                          setSearchResults([]);
                        }}
                        className="w-full px-3 py-2 text-left hover:bg-zinc-700 text-white text-sm"
                      >
                        {citizen.charinfo?.firstname} {citizen.charinfo?.lastname}
                        <span className="text-zinc-500 ml-2">({citizen.citizenid})</span>
                        {citizen.isStaff && (
                          <span className="text-amber-400 text-xs ml-2">Already Staff</span>
                        )}
                      </button>
                    ))}
                  </div>
                )}
              </div>

              <div>
                <label className="block text-zinc-400 text-sm mb-1">Department & Grade</label>
                <select
                  value={newStaffRole}
                  onChange={(e) => {
                    const [deptName, gradeLevel] = e.target.value.split(':');
                    const dept = configRoles.find((r) => r.name === deptName);
                    const grade = dept?.grades.find((g) => g.level === parseInt(gradeLevel));
                    setNewStaffRole(e.target.value);
                    setNewStaffPermissions(grade?.permissions || {});
                  }}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white focus:outline-none focus:border-amber-600"
                >
                  {configRoles.map((dept) => (
                    <optgroup key={dept.name} label={dept.label}>
                      {dept.grades.map((grade) => (
                        <option key={`${dept.name}:${grade.level}`} value={`${dept.name}:${grade.level}`}>
                          {grade.label}
                        </option>
                      ))}
                    </optgroup>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-zinc-400 text-sm mb-2">Permissions Override</label>
                <div className="space-y-2">
                  {renderPermissionToggle('canCreateRecords', 'Create Records', newStaffPermissions.canCreateRecords, (v) =>
                    setNewStaffPermissions({ ...newStaffPermissions, canCreateRecords: v })
                  )}
                  {renderPermissionToggle('canDeleteRecords', 'Delete Records', newStaffPermissions.canDeleteRecords, (v) =>
                    setNewStaffPermissions({ ...newStaffPermissions, canDeleteRecords: v })
                  )}
                  {renderPermissionToggle('canManageWarrants', 'Manage Warrants', newStaffPermissions.canManageWarrants, (v) =>
                    setNewStaffPermissions({ ...newStaffPermissions, canManageWarrants: v })
                  )}
                  {renderPermissionToggle('isAdmin', 'Admin', newStaffPermissions.isAdmin, (v) =>
                    setNewStaffPermissions({ ...newStaffPermissions, isAdmin: v })
                  )}
                </div>
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleAddStaff}
                disabled={!newStaffCitizenid}
                className="flex-1 bg-amber-600 hover:bg-amber-500 disabled:bg-zinc-700 disabled:text-zinc-500 py-2 rounded-lg text-white font-medium transition-colors"
              >
                Add Staff
              </button>
              <button
                onClick={() => {
                  setShowAddModal(false);
                  setNewStaffCitizenid('');
                  setSearchQuery('');
                  setSearchResults([]);
                }}
                className="flex-1 bg-zinc-700 hover:bg-zinc-600 py-2 rounded-lg text-white font-medium transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {showEditModal && editingStaff && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div className="absolute inset-0 bg-black/70" onClick={() => setShowEditModal(false)} />
          <div className="relative bg-zinc-900 border border-zinc-700 rounded-xl w-full max-w-md p-6">
            <h3 className="text-white text-lg font-bold mb-4">Edit Staff Member</h3>
            <p className="text-zinc-400 text-sm mb-4">
              {editingStaff.name} <span className="text-zinc-500">({editingStaff.citizenid})</span>
            </p>

            <div className="space-y-4">
              <div>
                <label className="block text-zinc-400 text-sm mb-1">Department & Grade</label>
                <select
                  value={editingStaff.role}
                  onChange={(e) => {
                    const [deptName, gradeLevel] = e.target.value.split(':');
                    const dept = configRoles.find((r) => r.name === deptName);
                    const grade = dept?.grades.find((g) => g.level === parseInt(gradeLevel));
                    setEditingStaff({
                      ...editingStaff,
                      role: e.target.value,
                      role_label: grade?.label,
                      permissions: grade?.permissions || editingStaff.permissions,
                    });
                  }}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white focus:outline-none focus:border-amber-600"
                >
                  {configRoles.map((dept) => (
                    <optgroup key={dept.name} label={dept.label}>
                      {dept.grades.map((grade) => (
                        <option key={`${dept.name}:${grade.level}`} value={`${dept.name}:${grade.level}`}>
                          {grade.label}
                        </option>
                      ))}
                    </optgroup>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-zinc-400 text-sm mb-2">Permissions</label>
                <div className="space-y-2">
                  {renderPermissionToggle(
                    'canCreateRecords',
                    'Create Records',
                    editingStaff.permissions?.canCreateRecords,
                    (v) => setEditingStaff({ ...editingStaff, permissions: { ...editingStaff.permissions, canCreateRecords: v } })
                  )}
                  {renderPermissionToggle(
                    'canDeleteRecords',
                    'Delete Records',
                    editingStaff.permissions?.canDeleteRecords,
                    (v) => setEditingStaff({ ...editingStaff, permissions: { ...editingStaff.permissions, canDeleteRecords: v } })
                  )}
                  {renderPermissionToggle(
                    'canManageWarrants',
                    'Manage Warrants',
                    editingStaff.permissions?.canManageWarrants,
                    (v) => setEditingStaff({ ...editingStaff, permissions: { ...editingStaff.permissions, canManageWarrants: v } })
                  )}
                  {renderPermissionToggle(
                    'isAdmin',
                    'Admin',
                    editingStaff.permissions?.isAdmin,
                    (v) => setEditingStaff({ ...editingStaff, permissions: { ...editingStaff.permissions, isAdmin: v } })
                  )}
                </div>
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleUpdateStaff}
                className="flex-1 bg-amber-600 hover:bg-amber-500 py-2 rounded-lg text-white font-medium transition-colors"
              >
                Save Changes
              </button>
              <button
                onClick={() => {
                  setShowEditModal(false);
                  setEditingStaff(null);
                }}
                className="flex-1 bg-zinc-700 hover:bg-zinc-600 py-2 rounded-lg text-white font-medium transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {showConfirm && (
        <ConfirmModal
          title="Remove Staff Member"
          message={`Are you sure you want to remove ${showConfirm.data.name} from staff?`}
          confirmLabel="Remove"
          onConfirm={() => handleRemoveStaff(showConfirm.data.citizenid)}
          onCancel={() => setShowConfirm(null)}
        />
      )}

      {selectedOfficer && (
        <OfficerDetailModal
          officer={selectedOfficer}
          lawJobs={lawJobs}
          onClose={() => setSelectedOfficer(null)}
          onUpdated={async () => {
            await Promise.all([fetchStaff(), fetchOfficers()]);
          }}
        />
      )}
    </div>
  );
}
