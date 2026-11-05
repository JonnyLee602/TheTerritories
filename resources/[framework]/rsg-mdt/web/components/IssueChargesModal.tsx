import { useState, useEffect, useMemo, useCallback } from 'react';
import { fetchNui, useNuiEvent } from '../hooks/useNui';
import { ReportSelector } from './ReportSelector';
import { Toast, createToast, type ToastType } from './Toast';
import type { ChargeTemplate, ReportForAttachment, JailConfig, JailStatus } from '../types';

interface IssueChargesModalProps {
  citizenid: string;
  citizenName: string;
  onClose: () => void;
  onIssued?: () => void;
  targetPlayerId?: number;
}

const categoryColors: Record<string, string> = {
  felony: 'bg-red-950/50 text-red-400 border-red-800',
  misdemeanor: 'bg-amber-950/50 text-amber-400 border-amber-800',
  infraction: 'bg-blue-950/50 text-blue-400 border-blue-800',
};

export function IssueChargesModal({ citizenid, citizenName, onClose, onIssued, targetPlayerId }: IssueChargesModalProps) {
  const [templates, setTemplates] = useState<ChargeTemplate[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [searchQuery, setSearchQuery] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showReportSelector, setShowReportSelector] = useState(false);
  const [attachedReports, setAttachedReports] = useState<ReportForAttachment[]>([]);
  const [toast, setToast] = useState<{ id: string; message: string; type: ToastType } | null>(null);
  const [jailConfig, setJailConfig] = useState<JailConfig | null>(null);
  const [jailStatus, setJailStatus] = useState<JailStatus>({ status: 'idle' });

  useEffect(() => {
    const loadTemplates = async () => {
      const result = await fetchNui<ChargeTemplate[]>('getChargeTemplates', {}, []);
      setTemplates(result);
    };
    loadTemplates();

    const loadJailConfig = async () => {
      const config = await fetchNui<JailConfig>('getJailConfig', {}, {
        delaySeconds: 5,
        maxDistance: 10.0,
        jailCoords: { x: 0, y: 0, z: 0 },
        jailHeading: 0,
        enabled: true,
        minutesPerMonth: 1,
        maxJailDistance: 100.0
      });
      setJailConfig(config);
    };
    loadJailConfig();
  }, []);

  useNuiEvent<JailStatus>('jailStatus', (data) => {
    setJailStatus(data);
    if (data.status === 'completed') {
      onIssued?.();
      onClose();
    }
  });

  const filteredTemplates = useMemo(() => {
    if (!searchQuery.trim()) return templates;
    const query = searchQuery.toLowerCase();
    return templates.filter(t =>
      t.name.toLowerCase().includes(query) ||
      (t.description && t.description.toLowerCase().includes(query)) ||
      t.category.toLowerCase().includes(query)
    );
  }, [templates, searchQuery]);

  const selectedCharges = useMemo(() => {
    return templates.filter(t => selectedIds.has(t.id));
  }, [templates, selectedIds]);

  const totals = useMemo(() => {
    return selectedCharges.reduce(
      (acc, c) => ({ fine: acc.fine + c.fine, jailtime: acc.jailtime + c.jailtime }),
      { fine: 0, jailtime: 0 }
    );
  }, [selectedCharges]);

  const willJail = totals.jailtime > 0 && targetPlayerId && jailConfig?.enabled;
  const isJailProcessing = jailStatus.status === 'processing';

  const toggleCharge = (id: number) => {
    const newSet = new Set(selectedIds);
    if (newSet.has(id)) {
      newSet.delete(id);
    } else {
      newSet.add(id);
    }
    setSelectedIds(newSet);
  };

  const showToast = useCallback((message: string, type: ToastType = 'info') => {
    setToast(createToast(message, type));
  }, []);

  const removeToast = useCallback(() => {
    setToast(null);
  }, []);

  const handleAttachReports = (reportIds: number[]) => {
    if (reportIds.length === 0) return;
    
    const newReports = reportIds
      .filter(id => !attachedReports.find(r => r.id === id))
      .map(id => ({
        id,
        title: `Report #${id}`,
        type: 'incident',
        officer: 'Unknown',
        created_at: new Date().toISOString(),
      }));
    
    setAttachedReports(prev => [...prev, ...newReports]);
    showToast(`${reportIds.length} report(s) attached`, 'success');
  };

  const removeAttachedReport = (reportId: number) => {
    setAttachedReports(prev => prev.filter(r => r.id !== reportId));
  };

  const handleSubmit = async () => {
    if (selectedCharges.length === 0) {
      setError('Select at least one charge');
      return;
    }

    if (totals.jailtime > 0 && !targetPlayerId) {
      setError('Cannot issue jail time - player is offline. Remove jail charges or wait for player to come online.');
      return;
    }

    setSubmitting(true);
    setError(null);

    if (willJail) {
      setJailStatus({ status: 'processing', remaining: jailConfig?.delaySeconds || 5 });
    }

    const result = await fetchNui<{ success: boolean; message: string; jailed?: boolean; totalJailtime?: number }>(
      'submitCharges',
      {
        citizenid,
        targetPlayerId,
        citizenName,
        charges: selectedCharges.map(c => ({
          templateId: c.id,
          name: c.name,
          description: c.description || undefined,
          fine: c.fine,
          jailtime: c.jailtime,
        })),
        totalJailtime: totals.jailtime,
        attachedReportIds: attachedReports.map(r => r.id),
      },
      { success: true, message: 'Charges submitted', jailed: totals.jailtime > 0 }
    );

    if (!result.success) {
      setError(result.message || 'Failed to submit charges');
      setJailStatus({ status: 'failed', message: result.message });
      setSubmitting(false);
    }
  };

  const getSubmitButtonText = () => {
    if (isJailProcessing && jailStatus.remaining) {
      return `${jailStatus.remaining}s`;
    }
    if (willJail) {
      return `Submit & Jail (${totals.jailtime}mo)`;
    }
    return 'Submit Charges';
  };

  const getSubmitButtonTooltip = () => {
    if (totals.jailtime > 0 && !targetPlayerId) {
      return 'Player is offline - cannot issue jail time';
    }
    if (willJail) {
      return `Will jail ${citizenName} for ${totals.jailtime * (jailConfig?.minutesPerMonth || 1)} minutes`;
    }
    return null;
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center" onClick={onClose}>
      <div className="absolute inset-0 bg-black/70" />
      <div
        className="relative bg-zinc-900 border border-zinc-700 rounded-xl w-full max-w-5xl max-h-[90vh] overflow-hidden shadow-2xl"
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-zinc-800">
          <div>
            <h3 className="text-white text-xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
              Issue Charges
            </h3>
            <p className="text-zinc-400 text-sm mt-1">
              To: <span className="text-amber-400">{citizenName}</span>
              {targetPlayerId ? (
                <span className="ml-2 text-green-400">(Online)</span>
              ) : (
                <span className="ml-2 text-red-400">(Offline)</span>
              )}
            </p>
          </div>
          <button onClick={onClose} className="text-zinc-400 hover:text-white transition-colors">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="flex h-[calc(90vh-140px)]">
          <div className="w-2/5 border-r border-zinc-800 flex flex-col">
            <div className="p-4 border-b border-zinc-800">
              <input
                type="text"
                placeholder="Search charges..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
              />
            </div>

            <div className="flex-1 overflow-y-auto p-4 space-y-2">
              {filteredTemplates.length === 0 ? (
                <p className="text-zinc-500 text-center py-8">No charges found</p>
              ) : (
                filteredTemplates.map(charge => (
                  <button
                    key={charge.id}
                    onClick={() => toggleCharge(charge.id)}
                    className={`w-full text-left p-3 rounded-lg border transition-all ${
                      selectedIds.has(charge.id)
                        ? 'bg-amber-600/20 border-amber-600'
                        : 'bg-zinc-800/50 border-zinc-700 hover:border-zinc-600'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <span className="text-white font-medium">{charge.name}</span>
                          <span className={`text-xs px-2 py-0.5 rounded border ${categoryColors[charge.category] || 'bg-zinc-800 text-zinc-400'}`}>
                            {charge.category}
                          </span>
                        </div>
                        {charge.description && (
                          <p className="text-zinc-400 text-sm mt-1 line-clamp-2">{charge.description}</p>
                        )}
                      </div>
                      <div className="flex-shrink-0 text-right">
                        {charge.fine > 0 && (
                          <p className="text-amber-400 text-sm font-medium">${charge.fine}</p>
                        )}
                        {charge.jailtime > 0 && (
                          <p className="text-red-400 text-xs">{charge.jailtime}mo</p>
                        )}
                      </div>
                    </div>
                  </button>
                ))
              )}
            </div>
          </div>

          <div className="w-3/5 flex flex-col">
            <div className="p-4 border-b border-zinc-800">
              <h4 className="text-zinc-300 font-bold">Selected Charges ({selectedCharges.length})</h4>
            </div>

            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              <div className="space-y-2">
                {selectedCharges.length === 0 ? (
                  <p className="text-zinc-500 text-center py-4">No charges selected</p>
                ) : (
                  selectedCharges.map(charge => (
                    <div
                      key={charge.id}
                      className="bg-zinc-800/50 border border-zinc-700 rounded-lg p-3"
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-white font-medium">{charge.name}</span>
                        <button
                          onClick={() => toggleCharge(charge.id)}
                          className="text-zinc-400 hover:text-red-400 transition-colors"
                        >
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                          </svg>
                        </button>
                      </div>
                      <div className="flex gap-4 mt-2 text-sm">
                        {charge.fine > 0 && <span className="text-amber-400">Fine: ${charge.fine}</span>}
                        {charge.jailtime > 0 && <span className="text-red-400">Jail: {charge.jailtime}mo</span>}
                      </div>
                    </div>
                  ))
                )}
              </div>

              <div className="border-t border-zinc-800 pt-4">
                <div className="flex items-center justify-between mb-3">
                  <h4 className="text-zinc-300 font-bold text-sm">
                    Attached Reports ({attachedReports.length})
                  </h4>
                  <button
                    onClick={() => setShowReportSelector(true)}
                    className="flex items-center gap-1.5 bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 rounded-lg px-3 py-1.5 text-zinc-300 text-sm transition-colors"
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                    </svg>
                    Attach Report
                  </button>
                </div>

                {attachedReports.length === 0 ? (
                  <div className="bg-zinc-800/30 border border-zinc-800 border-dashed rounded-lg p-4 text-center">
                    <svg className="w-6 h-6 text-zinc-600 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <p className="text-zinc-500 text-xs">No reports attached yet</p>
                  </div>
                ) : (
                  <div className="space-y-2">
                    {attachedReports.map(report => (
                      <div
                        key={report.id}
                        className="bg-zinc-800/50 border border-zinc-700/50 rounded-lg p-2.5 flex items-center justify-between group"
                      >
                        <div className="flex items-center gap-2 min-w-0">
                          <svg className="w-4 h-4 text-zinc-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          <span className="text-zinc-300 text-sm truncate">{report.title}</span>
                          <span className="text-zinc-600 text-xs">#{report.id}</span>
                        </div>
                        <button
                          onClick={() => removeAttachedReport(report.id)}
                          className="text-zinc-500 hover:text-red-400 transition-colors opacity-0 group-hover:opacity-100"
                        >
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                          </svg>
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            <div className="p-4 border-t border-zinc-800 bg-zinc-900/50">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <p className="text-zinc-400 text-sm">Total Fine</p>
                  <p className="text-amber-400 text-2xl font-bold">${totals.fine}</p>
                </div>
                <div className="text-right">
                  <p className="text-zinc-400 text-sm">Total Jail Time</p>
                  <p className="text-red-400 text-2xl font-bold">{totals.jailtime} mo</p>
                </div>
              </div>

              {totals.jailtime > 0 && !targetPlayerId && (
                <div className="mb-3 bg-red-950/30 border border-red-800/50 rounded-lg px-4 py-2 flex items-center gap-2">
                  <svg className="w-5 h-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                  <span className="text-red-400 text-sm">Cannot jail offline player. Remove jail charges to proceed.</span>
                </div>
              )}

              {error && (
                <p className="text-red-400 text-sm mb-3 text-center">{error}</p>
              )}

              {isJailProcessing && (
                <div className="mb-3 bg-orange-950/30 border border-orange-800/50 rounded-lg px-4 py-2 flex items-center justify-center gap-3">
                  <svg className="w-5 h-5 animate-spin text-orange-400" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
                  </svg>
                  <span className="text-orange-400 font-medium">
                    Processing... {jailStatus.remaining}s remaining (Stay within {jailConfig?.maxDistance}m)
                  </span>
                </div>
              )}

              <div className="flex gap-3">
                <button
                  onClick={onClose}
                  disabled={isJailProcessing}
                  className="flex-1 bg-zinc-700 hover:bg-zinc-600 disabled:opacity-50 rounded-lg px-4 py-2.5 text-white font-medium transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSubmit}
                  disabled={submitting || selectedCharges.length === 0 || isJailProcessing || (totals.jailtime > 0 && !targetPlayerId)}
                  title={getSubmitButtonTooltip() || undefined}
                  className={`flex-1 rounded-lg px-4 py-2.5 text-white font-medium transition-colors flex items-center justify-center gap-2 disabled:bg-zinc-700 disabled:text-zinc-400 ${
                    willJail 
                      ? 'bg-orange-600 hover:bg-orange-500' 
                      : 'bg-amber-600 hover:bg-amber-500'
                  }`}
                >
                  {isJailProcessing ? (
                    <>
                      <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
                      </svg>
                      <span>{jailStatus.remaining}s</span>
                    </>
                  ) : (
                    <span>{getSubmitButtonText()}</span>
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <ReportSelector
        isOpen={showReportSelector}
        onClose={() => setShowReportSelector(false)}
        onConfirm={handleAttachReports}
        alreadyAttachedIds={attachedReports.map(r => r.id)}
      />

      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={removeToast}
        />
      )}
    </div>
  );
}
