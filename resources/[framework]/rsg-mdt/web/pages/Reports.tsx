import React, { useState, useEffect } from 'react';
import { fetchNui, useNuiEvent } from '../hooks/useNui';
import { useConfirmDialog } from '../components/ConfirmDialog';
import type { Report, ReportComment, IncidentType } from '../types';

interface ReportsProps {
  onRefresh?: () => void;
  viewingReportId?: number | null;
  onViewCharge?: (chargeId: number) => void;
  onReportViewed?: () => void;
}

export function Reports({ onRefresh, viewingReportId, onViewCharge, onReportViewed }: ReportsProps) {
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [selectedReport, setSelectedReport] = useState<Report | null>(null);
  const [comments, setComments] = useState<ReportComment[]>([]);
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [newComment, setNewComment] = useState('');
  const [incidentTypes, setIncidentTypes] = useState<IncidentType[]>([]);
  const [form, setForm] = useState({ title: '', type: 'incident', description: '', officers: '', suspects: '', evidence: '' });
  const { confirm, dialog } = useConfirmDialog();

  useEffect(() => {
    if (viewingReportId && reports.length > 0) {
      const report = reports.find(r => r.id === viewingReportId);
      if (report) {
        setSelectedReport(report);
        loadComments(report.id);
        onReportViewed?.();
      }
    }
  }, [viewingReportId, reports]);

  const loadIncidentTypes = async () => {
    const types = await fetchNui<IncidentType[]>('getIncidentTypes', {}, [
      { value: 'incident', label: 'Incident', color: 'bg-red-950/50 text-red-400 border-red-900' },
      { value: 'arrest', label: 'Arrest', color: 'bg-orange-950/50 text-orange-400 border-orange-900' },
      { value: 'investigation', label: 'Investigation', color: 'bg-blue-950/50 text-blue-400 border-blue-900' },
      { value: 'traffic', label: 'Traffic', color: 'bg-green-950/50 text-green-400 border-green-900' },
    ]);
    setIncidentTypes(types);
    if (types.length > 0 && !form.type) {
      setForm(prev => ({ ...prev, type: types[0].value }));
    }
  };

  const loadReports = async () => {
    setLoading(true);
    const data = await fetchNui<Report[]>('getReports', {}, [
      { id: 1, title: 'Bank Robbery Incident', type: 'incident', description: 'Armed robbery at the Rhodes Bank. Suspects fled on horseback heading north.', officers: ['Marshal Davis', 'Deputy Miller'], suspects: ['Unknown Male #1', 'Unknown Male #2'], evidence: ['Witness testimony', 'Shell casings'], officer: 'Marshal Davis', created_at: '1899-05-15 14:30:00' },
      { id: 2, title: 'Assault Report', type: 'arrest', description: 'Bar fight at the saloon resulting in minor injuries.', officers: ['Sheriff Johnson'], suspects: ['Thomas Downes'], evidence: ['Witness statements'], officer: 'Sheriff Johnson', created_at: '1899-06-02 21:15:00' },
    ]);
    setReports(data);
    setLoading(false);
  };

  useEffect(() => { loadReports(); loadIncidentTypes(); }, []);

  const loadComments = async (reportId: number) => {
    setCommentsLoading(true);
    const data = await fetchNui<ReportComment[]>('getReportComments', { reportId }, [
      { id: 1, report_id: 1, author: 'Deputy Miller', content: 'Found tire tracks leading toward the swamps. Sent samples to forensics.', created_at: '1899-05-16 09:00:00' },
      { id: 2, report_id: 1, author: 'Marshal Davis', content: 'Witness came forward with a description. Male, approximately 6ft, dark coat.', created_at: '1899-05-17 15:30:00' },
    ]);
    setComments(data);
    setCommentsLoading(false);
  };

  const handleSelectReport = (report: Report) => {
    setSelectedReport(report);
    setNewComment('');
    loadComments(report.id);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const data = {
      ...form,
      officers: form.officers.split(',').map(s => s.trim()).filter(Boolean),
      suspects: form.suspects.split(',').map(s => s.trim()).filter(Boolean),
      evidence: form.evidence.split(',').map(s => s.trim()).filter(Boolean),
    };
    const success = await fetchNui<{ success: boolean }>('createReport', data, { success: true });
    if (success.success) {
      setShowForm(false);
      setForm({ title: '', type: 'incident', description: '', officers: '', suspects: '', evidence: '' });
      loadReports();
      onRefresh?.();
    }
  };

  const handleAddComment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedReport || !newComment.trim()) return;
    
    const success = await fetchNui<{ success: boolean }>('addReportComment', { 
      reportId: selectedReport.id, 
      content: newComment 
    }, { success: true });
    
    if (success.success) {
      setNewComment('');
      loadComments(selectedReport.id);
    }
  };

  const handleDelete = async (id: number) => {
    const confirmed = await confirm('Delete Report', 'Are you sure you want to delete this report? This action cannot be undone.');
    if (!confirmed) return;
    fetchNui('deleteReport', { id }, { success: true });
  };

  useNuiEvent<{ success: boolean; id: number }>('reportDeleted', (data) => {
    if (data.success) {
      if (selectedReport?.id === data.id) {
        setSelectedReport(null);
      }
      loadReports();
      onRefresh?.();
    }
  });

  const formatDate = (dateStr: unknown) => {
    if (!dateStr) {
      console.log('[MDT] formatDate: dateStr is falsy:', dateStr);
      return 'Unknown';
    }
    
    // Handle string format (MySQL DATETIME)
    if (typeof dateStr === 'string') {
      return dateStr.replace('T', ' ').split('.')[0];
    }
    
    // Handle number (Unix timestamp in seconds or milliseconds)
    if (typeof dateStr === 'number') {
      const date = new Date(dateStr * (dateStr < 10000000000 ? 1000 : 1));
      return date.toISOString().replace('T', ' ').split('.')[0];
    }
    
    // Handle Date object
    if (dateStr instanceof Date) {
      return dateStr.toISOString().replace('T', ' ').split('.')[0];
    }
    
    console.log('[MDT] formatDate: unexpected type:', typeof dateStr, dateStr);
    return 'Unknown';
  };

  const ensureArray = (value: unknown): string[] => {
    if (Array.isArray(value)) return value;
    if (typeof value === 'string') {
      try {
        const parsed = JSON.parse(value);
        return Array.isArray(parsed) ? parsed : [];
      } catch {
        return [];
      }
    }
    return [];
  };

  const getTypeColor = (type: string): string => {
    const found = incidentTypes.find(t => t.value === type);
    return found?.color || 'bg-zinc-950/50 text-zinc-400 border-zinc-700';
  };

  const getTypeLabel = (type: string): string => {
    const found = incidentTypes.find(t => t.value === type);
    return found?.label || type;
  };

  return (
    <div className="space-y-6">
      {dialog}
      <div className="flex justify-between items-center">
        <h2 className="text-white text-2xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
          Reports
        </h2>
        <button
          onClick={() => setShowForm(true)}
          className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded-lg text-white text-sm transition-colors"
        >
          + New Report
        </button>
      </div>

      {showForm && !selectedReport && (
        <form onSubmit={handleSubmit} className="bg-zinc-900 border border-zinc-800 rounded-lg p-6 space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <input
              placeholder="Report Title"
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
              required
            />
            <select
              value={form.type}
              onChange={(e) => setForm({ ...form, type: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white focus:outline-none focus:border-blue-600"
            >
              {incidentTypes.map((t) => (
                <option key={t.value} value={t.value}>{t.label}</option>
              ))}
            </select>
          </div>
          <textarea
            placeholder="Description"
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
            className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-blue-600 h-32"
            required
          />
          <div className="grid grid-cols-3 gap-4">
            <input
              placeholder="Officers (comma separated)"
              value={form.officers}
              onChange={(e) => setForm({ ...form, officers: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
            />
            <input
              placeholder="Suspects (comma separated)"
              value={form.suspects}
              onChange={(e) => setForm({ ...form, suspects: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
            />
            <input
              placeholder="Evidence (comma separated)"
              value={form.evidence}
              onChange={(e) => setForm({ ...form, evidence: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
            />
          </div>
          <div className="flex gap-3">
            <button type="submit" className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded text-white text-sm">
              Submit Report
            </button>
            <button type="button" onClick={() => setShowForm(false)} className="bg-zinc-800 hover:bg-zinc-700 px-4 py-2 rounded text-zinc-300 text-sm">
              Cancel
            </button>
          </div>
        </form>
      )}

      {selectedReport && (
        <div className="bg-zinc-900 border border-zinc-800 rounded-lg overflow-hidden">
          {/* Header */}
          <div className="bg-zinc-800/50 px-6 py-4 border-b border-zinc-800 flex justify-between items-center">
            <div className="flex items-center gap-3">
              <span className={`px-2 py-0.5 rounded text-xs uppercase border ${getTypeColor(selectedReport.type)}`}>
                {getTypeLabel(selectedReport.type)}
              </span>
              <h3 className="text-white text-lg font-bold">{selectedReport.title}</h3>
            </div>
            <button onClick={() => setSelectedReport(null)} className="text-zinc-400 hover:text-white text-sm transition-colors">
              ← Back to Reports
            </button>
          </div>

          <div className="grid grid-cols-3 divide-x divide-zinc-800">
            {/* Main Content */}
            <div className="col-span-2 p-6 space-y-6">
              {/* Description */}
              <div>
                <h4 className="text-zinc-500 text-xs uppercase tracking-wider mb-2">Description</h4>
                <p className="text-zinc-300 leading-relaxed">{selectedReport.description}</p>
              </div>

              {/* Details Grid */}
              <div className="grid grid-cols-3 gap-4">
                {ensureArray(selectedReport.officers).length > 0 && (
                  <div className="bg-zinc-800/50 rounded-lg p-4">
                    <p className="text-zinc-500 text-xs uppercase mb-2">Officers</p>
                    <ul className="space-y-1">
                      {ensureArray(selectedReport.officers).map((o, i) => (
                        <li key={i} className="text-zinc-300 text-sm flex items-center gap-2">
                          <span className="w-1.5 h-1.5 bg-blue-500 rounded-full"></span>
                          {o}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
                {ensureArray(selectedReport.suspects).length > 0 && (
                  <div className="bg-zinc-800/50 rounded-lg p-4">
                    <p className="text-zinc-500 text-xs uppercase mb-2">Suspects</p>
                    <ul className="space-y-1">
                      {ensureArray(selectedReport.suspects).map((s, i) => (
                        <li key={i} className="text-zinc-300 text-sm flex items-center gap-2">
                          <span className="w-1.5 h-1.5 bg-red-500 rounded-full"></span>
                          {s}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
                {ensureArray(selectedReport.evidence).length > 0 && (
                  <div className="bg-zinc-800/50 rounded-lg p-4">
                    <p className="text-zinc-500 text-xs uppercase mb-2">Evidence</p>
                    <ul className="space-y-1">
                      {ensureArray(selectedReport.evidence).map((e, i) => (
                        <li key={i} className="text-zinc-300 text-sm flex items-center gap-2">
                          <span className="w-1.5 h-1.5 bg-amber-500 rounded-full"></span>
                          {e}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </div>

              {/* Case History / Comments */}
              <div>
                <h4 className="text-zinc-500 text-xs uppercase tracking-wider mb-3 flex items-center gap-2">
                  Case History
                  <span className="bg-zinc-800 text-zinc-400 px-2 py-0.5 rounded text-xs">
                    {comments.length} entries
                  </span>
                </h4>

                {commentsLoading ? (
                  <p className="text-zinc-500 text-sm">Loading case history...</p>
                ) : comments.length === 0 ? (
                  <div className="bg-zinc-800/30 border border-zinc-800 border-dashed rounded-lg p-6 text-center">
                    <p className="text-zinc-500 text-sm">No case history yet. Add comments to build up the case.</p>
                  </div>
                ) : (
                  <div className="space-y-3 max-h-64 overflow-y-auto pr-2">
                    {comments.map((comment) => (
                      <div key={comment.id} className="bg-zinc-800/50 border border-zinc-700/50 rounded-lg p-4">
                        <div className="flex items-center gap-2 mb-2">
                          <span className="text-amber-400 font-medium text-sm">{comment.author}</span>
                          <span className="text-zinc-600 text-xs">•</span>
                          <span className="text-zinc-500 text-xs">{formatDate(comment.created_at)}</span>
                        </div>
                        <p className="text-zinc-300 text-sm leading-relaxed">{comment.content}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Add Comment Form */}
              <form onSubmit={handleAddComment} className="bg-zinc-800/30 border border-zinc-700/50 rounded-lg p-4">
                <label className="text-zinc-500 text-xs uppercase tracking-wider mb-2 block">Add Case Note</label>
                <div className="flex gap-3">
                  <textarea
                    value={newComment}
                    onChange={(e) => setNewComment(e.target.value)}
                    placeholder="Add investigation notes, updates, or additional findings..."
                    className="flex-1 bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600 text-sm resize-none"
                    rows={2}
                  />
                </div>
                <div className="flex justify-end mt-3">
                  <button
                    type="submit"
                    disabled={!newComment.trim()}
                    className="bg-amber-600 hover:bg-amber-500 disabled:bg-zinc-700 disabled:text-zinc-500 px-4 py-2 rounded text-white text-sm transition-colors"
                  >
                    Add Note
                  </button>
                </div>
              </form>
            </div>

            {/* Sidebar */}
            <div className="p-6 bg-zinc-900/50">
              <h4 className="text-zinc-500 text-xs uppercase tracking-wider mb-4">Report Info</h4>
              
              <div className="space-y-4">
                <div>
                  <p className="text-zinc-600 text-xs">Filed By</p>
                  <p className="text-white font-medium">{selectedReport.officer}</p>
                </div>
                <div>
                  <p className="text-zinc-600 text-xs">Date Filed</p>
                  <p className="text-zinc-300 text-sm">{formatDate(selectedReport.created_at)}</p>
                </div>
                {selectedReport.officer_cid && (
                  <div>
                    <p className="text-zinc-600 text-xs">Officer ID</p>
                    <p className="text-zinc-400 text-sm font-mono">{selectedReport.officer_cid}</p>
                  </div>
                )}
                <div>
                  <p className="text-zinc-600 text-xs">Report ID</p>
                  <p className="text-zinc-400 text-sm font-mono">#{selectedReport.id}</p>
                </div>
                {selectedReport.linkedCharge && (
                  <div className="bg-amber-950/30 border border-amber-800/50 rounded-lg p-3">
                    <p className="text-amber-400 text-xs uppercase tracking-wider mb-2 flex items-center gap-1">
                      <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                      </svg>
                      Linked Charge
                    </p>
                    <p className="text-white font-medium text-sm">{selectedReport.linkedCharge.charge_name}</p>
                    <p className="text-zinc-400 text-xs mt-1">{selectedReport.linkedCharge.citizen_name}</p>
                    <div className="flex gap-3 mt-2 text-xs">
                      {selectedReport.linkedCharge.fine > 0 && (
                        <span className="text-amber-400">${selectedReport.linkedCharge.fine}</span>
                      )}
                      {selectedReport.linkedCharge.jailtime > 0 && (
                        <span className="text-red-400">{selectedReport.linkedCharge.jailtime} mo</span>
                      )}
                    </div>
                    {onViewCharge && (
                      <button
                        onClick={() => onViewCharge(selectedReport.linkedCharge!.charge_id)}
                        className="mt-3 w-full bg-amber-600 hover:bg-amber-500 text-white py-2 rounded text-sm transition-colors"
                      >
                        View Charge Details
                      </button>
                    )}
                  </div>
                )}
              </div>

              <div className="mt-6 pt-6 border-t border-zinc-800">
                <button
                  onClick={() => handleDelete(selectedReport.id)}
                  className="w-full bg-red-950/50 hover:bg-red-900/50 text-red-400 py-2 rounded text-sm transition-colors"
                >
                  Delete Report
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {!selectedReport && (
        loading ? (
          <p className="text-zinc-500">Loading reports...</p>
        ) : reports.length === 0 ? (
          <p className="text-zinc-500">No reports filed.</p>
        ) : (
          <div className="space-y-3">
            {reports.map((report) => (
              <div
                key={report.id}
                onClick={() => handleSelectReport(report)}
                className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-4 cursor-pointer hover:bg-zinc-800/50 hover:border-zinc-700 transition-all group"
              >
                <div className="flex justify-between items-start">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className={`px-2 py-0.5 rounded text-xs uppercase border ${getTypeColor(report.type)}`}>
                        {getTypeLabel(report.type)}
                      </span>
                      <h3 className="text-white font-bold group-hover:text-amber-400 transition-colors">{report.title}</h3>
                      {report.linkedCharge && (
                        <span className="bg-amber-950/50 text-amber-400 border border-amber-800 px-2 py-0.5 rounded text-xs flex items-center gap-1">
                          <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                          </svg>
                          Linked Charge
                        </span>
                      )}
                    </div>
                    <p className="text-zinc-500 text-sm mt-1 line-clamp-1">{report.description}</p>
                    <div className="flex gap-4 mt-2 text-xs text-zinc-600">
                      <span>{report.officer}</span>
                      <span>{formatDate(report.created_at)}</span>
                    </div>
                  </div>
                  <span className="text-zinc-600 group-hover:text-zinc-400 text-sm">→</span>
                </div>
              </div>
            ))}
          </div>
        )
      )}
    </div>
  );
}
