import { useState, useEffect } from 'react';
import { fetchNui, useNuiEvent } from '../hooks/useNui';
import { AttachmentsList } from './AttachmentsList';
import { ReportSelector } from './ReportSelector';
import { Toast, type ToastType } from './Toast';
import type { IssuedCharge, Fine } from '../types';

interface ChargeDetailModalProps {
  charge: IssuedCharge | null;
  onClose: () => void;
  onChargeUpdated?: (charge: IssuedCharge) => void;
  onViewReport?: (reportId: number) => void;
}

interface TimeRemaining {
  text: string;
  isOverdue: boolean;
  seconds: number;
}

function formatTimeRemaining(dueDate: string | null | undefined | number): TimeRemaining {
  if (!dueDate) {
    return { text: '', isOverdue: false, seconds: 0 };
  }
  
  let due: number;
  
  if (typeof dueDate === 'number') {
    if (dueDate > 1e12) {
      due = dueDate;
    } else if (dueDate > 1e9) {
      due = dueDate * 1000;
    } else {
      return { text: '', isOverdue: false, seconds: 0 };
    }
  } else {
    const dateStr = String(dueDate).trim();
    if (!dateStr || dateStr === 'null' || dateStr === 'undefined') {
      return { text: '', isOverdue: false, seconds: 0 };
    }
    
    let parsed: Date;
    if (dateStr.includes('T')) {
      parsed = new Date(dateStr);
    } else {
      parsed = new Date(dateStr.replace(' ', 'T') + 'Z');
    }
    
    due = parsed.getTime();
  }
  
  if (isNaN(due)) {
    return { text: '', isOverdue: false, seconds: 0 };
  }
  
  const now = Date.now();
  const remaining = due - now;
  
  if (remaining <= 0) {
    return { text: 'OVERDUE', isOverdue: true, seconds: 0 };
  }
  
  const MAX_DAYS = 365;
  const days = Math.floor(remaining / 86400000);
  
  if (days > MAX_DAYS) {
    return { text: '', isOverdue: false, seconds: 0 };
  }
  
  const hours = Math.floor((remaining % 86400000) / 3600000);
  const minutes = Math.floor((remaining % 3600000) / 60000);
  const seconds = Math.floor((remaining % 60000) / 1000);
  
  if (days > 0) {
    return { text: `${days} day${days !== 1 ? 's' : ''}, ${hours} hour${hours !== 1 ? 's' : ''}`, isOverdue: false, seconds: Math.floor(remaining / 1000) };
  } else if (hours > 0) {
    return { text: `${hours} hour${hours !== 1 ? 's' : ''}, ${minutes} min`, isOverdue: false, seconds: Math.floor(remaining / 1000) };
  } else {
    return { text: `${minutes}m ${seconds}s`, isOverdue: false, seconds: Math.floor(remaining / 1000) };
  }
}

export function ChargeDetailModal({ charge, onClose, onChargeUpdated, onViewReport }: ChargeDetailModalProps) {
  const [markingPaid, setMarkingPaid] = useState(false);
  const [showConfirmPaid, setShowConfirmPaid] = useState(false);
  const [localCharge, setLocalCharge] = useState<IssuedCharge | null>(charge);
  const [timeInfo, setTimeInfo] = useState<TimeRemaining>({ text: '', isOverdue: false, seconds: 0 });
  const [showReportSelector, setShowReportSelector] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  const [toast, setToast] = useState<{ message: string; type: ToastType } | null>(null);

  useEffect(() => {
    setLocalCharge(charge);
  }, [charge]);

  useEffect(() => {
    if (!localCharge?.due_date || localCharge.fine_status === 'paid') return;
    
    const updateTimer = () => {
      setTimeInfo(formatTimeRemaining(localCharge.due_date));
    };
    
    updateTimer();
    const interval = setInterval(updateTimer, 1000);
    return () => clearInterval(interval);
  }, [localCharge?.due_date, localCharge?.fine_status]);

  useNuiEvent<{ fineId: number; status: string; fine: Fine }>('fineStatusUpdated', (data) => {
    if (localCharge && data.fineId === localCharge.fine_id) {
      const updated = {
        ...localCharge,
        fine_status: 'paid' as const,
        paid_at: new Date().toISOString()
      };
      setLocalCharge(updated);
      onChargeUpdated?.(updated);
    }
  });

  if (!localCharge) return null;

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getCategoryStyle = () => {
    const fine = localCharge.fine || 0;
    const jailtime = localCharge.jailtime || 0;
    
    if (jailtime >= 12 || fine >= 100) {
      return { label: 'Felony', color: 'text-red-400 bg-red-400/10 border-red-400/30' };
    } else if (jailtime > 0 || fine >= 25) {
      return { label: 'Misdemeanor', color: 'text-amber-400 bg-amber-400/10 border-amber-400/30' };
    } else {
      return { label: 'Infraction', color: 'text-zinc-400 bg-zinc-400/10 border-zinc-400/30' };
    }
  };

  const handleMarkPaid = async () => {
    if (!localCharge.fine_id) return;
    
    setMarkingPaid(true);
    const result = await fetchNui<{ success: boolean; message: string; fine?: Fine }>(
      'markFinePaid',
      { fineId: localCharge.fine_id },
      { success: true, message: 'Fine marked as paid' }
    );
    
    if (result.success) {
      const updated = {
        ...localCharge,
        fine_status: 'paid' as const,
        paid_at: new Date().toISOString()
      };
      setLocalCharge(updated);
      onChargeUpdated?.(updated);
      setShowConfirmPaid(false);
    }
    
    setMarkingPaid(false);
  };

  const handleAttachReports = async (reportIds: number[]) => {
    if (reportIds.length === 0 || !localCharge) return;
    
    const result = await fetchNui<{ success: boolean; message: string; attachedCount?: number }>(
      'attachReportsToCharge',
      { chargeId: localCharge.id, reportIds },
      { success: true, message: 'Reports attached', attachedCount: reportIds.length }
    );
    
    if (result.success) {
      setToast({ message: result.message, type: 'success' });
      setRefreshKey(k => k + 1);
    } else {
      setToast({ message: result.message, type: 'error' });
    }
  };

  const category = getCategoryStyle();
  const canMarkPaid = localCharge.fine > 0 && localCharge.fine_id && localCharge.fine_status !== 'paid';

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center" onClick={onClose}>
      <div className="absolute inset-0 bg-black/80" />
      <div 
        className="relative bg-zinc-900 border border-zinc-700 rounded-xl w-full max-w-lg overflow-hidden shadow-2xl"
        onClick={e => e.stopPropagation()}
      >
        <div className="px-5 py-4 border-b border-zinc-800 bg-zinc-800/50">
          <div className="flex items-center justify-between">
            <h3 className="text-white text-lg font-bold" style={{ fontFamily: 'var(--font-display)' }}>
              Charge Details
            </h3>
            <button onClick={onClose} className="text-zinc-400 hover:text-white transition-colors">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        <div className="p-5 space-y-5">
          <div className="flex items-start justify-between">
            <div>
              <h4 className="text-xl font-bold text-white">{localCharge.charge_name}</h4>
              <div className="flex items-center gap-2 mt-1 flex-wrap">
                <span className={`inline-block text-xs px-2 py-1 rounded border ${category.color}`}>
                  {category.label}
                </span>
                {localCharge.fine > 0 && localCharge.fine_status && (
                  <span className={`inline-block text-xs px-2 py-1 rounded border ${
                    localCharge.fine_status === 'paid' 
                      ? 'text-green-400 bg-green-400/10 border-green-400/30'
                      : localCharge.fine_status === 'overdue'
                      ? 'text-red-400 bg-red-400/10 border-red-400/30'
                      : 'text-amber-400 bg-amber-400/10 border-amber-400/30'
                  }`}>
                    {localCharge.fine_status.charAt(0).toUpperCase() + localCharge.fine_status.slice(1)}
                  </span>
                )}
              </div>
            </div>
            <div className="text-right">
              <p className="text-zinc-500 text-xs">Charge ID</p>
              <p className="text-zinc-300 text-sm font-mono">#{localCharge.id}</p>
            </div>
          </div>

          {localCharge.charge_description && (
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-zinc-500 text-xs uppercase tracking-wider mb-1">Description</p>
              <p className="text-zinc-300 text-sm leading-relaxed">{localCharge.charge_description}</p>
            </div>
          )}

          <div className="grid grid-cols-2 gap-4">
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-zinc-500 text-xs uppercase tracking-wider mb-1">Fine</p>
              <p className={`text-2xl font-bold ${localCharge.fine > 0 ? 'text-amber-400' : 'text-zinc-500'}`}>
                {localCharge.fine > 0 ? `$${localCharge.fine}` : 'None'}
              </p>
              {localCharge.fine > 0 && localCharge.due_date && localCharge.fine_status !== 'paid' && (
                <div className="mt-2 pt-2 border-t border-zinc-700">
                  <p className="text-zinc-500 text-xs uppercase tracking-wider mb-1">
                    {timeInfo.isOverdue ? 'Overdue Since' : 'Time Remaining'}
                  </p>
                  <p className={`text-sm font-medium ${timeInfo.isOverdue ? 'text-red-400 animate-pulse' : 'text-amber-400'}`}>
                    {timeInfo.text}
                  </p>
                </div>
              )}
              {localCharge.fine_status === 'paid' && localCharge.paid_at && (
                <div className="mt-2 pt-2 border-t border-zinc-700">
                  <p className="text-zinc-500 text-xs uppercase tracking-wider mb-1">Paid On</p>
                  <p className="text-sm font-medium text-green-400">
                    {formatDate(localCharge.paid_at)}
                  </p>
                </div>
              )}
            </div>
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-zinc-500 text-xs uppercase tracking-wider mb-1">Jail Time</p>
              <p className={`text-2xl font-bold ${localCharge.jailtime > 0 ? 'text-red-400' : 'text-zinc-500'}`}>
                {localCharge.jailtime > 0 ? `${localCharge.jailtime} mo` : 'None'}
              </p>
            </div>
          </div>

          <div className="border-t border-zinc-800 pt-4 space-y-4">
            <h5 className="text-zinc-400 text-sm font-bold uppercase tracking-wider">Parties Involved</h5>
            
            <div className="bg-zinc-800/30 rounded-lg p-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-red-600/20 flex items-center justify-center">
                  <svg className="w-5 h-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
                  </svg>
                </div>
                <div>
                  <p className="text-zinc-500 text-xs">Charged Person</p>
                  <p className="text-white font-medium">{localCharge.citizen_name}</p>
                  <p className="text-zinc-500 text-xs font-mono">{localCharge.citizenid}</p>
                </div>
              </div>
            </div>

            <div className="bg-zinc-800/30 rounded-lg p-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-amber-600/20 flex items-center justify-center">
                  <svg className="w-5 h-5 text-amber-400" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                </div>
                <div>
                  <p className="text-zinc-500 text-xs">Issuing Officer</p>
                  <p className="text-white font-medium">{localCharge.officer}</p>
                  {localCharge.officer_cid && (
                    <p className="text-zinc-500 text-xs font-mono">{localCharge.officer_cid}</p>
                  )}
                </div>
              </div>
            </div>
          </div>

          <div className="border-t border-zinc-800 pt-4 space-y-3">
            <div className="flex items-center justify-between">
              <h5 className="text-zinc-400 text-sm font-bold uppercase tracking-wider">Attached Reports</h5>
              <button
                onClick={() => setShowReportSelector(true)}
                className="flex items-center gap-1.5 bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 rounded px-2.5 py-1 text-zinc-300 text-xs transition-colors"
              >
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                Attach Report
              </button>
            </div>
            <AttachmentsList
              key={refreshKey}
              chargeId={localCharge.id}
              onAttachmentChange={() => setRefreshKey(k => k + 1)}
              onViewReport={onViewReport}
            />
          </div>

          <div className="border-t border-zinc-800 pt-4">
            <div className="flex items-center justify-between text-sm">
              <div className="flex items-center gap-2 text-zinc-500">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <span>Issued on {formatDate(localCharge.created_at)}</span>
              </div>
              {localCharge.report_id && (
                <span className="text-zinc-500">
                  Report #{localCharge.report_id}
                </span>
              )}
            </div>
          </div>

          {canMarkPaid && (
            <div className="border-t border-zinc-800 pt-4">
              {!showConfirmPaid ? (
                <button
                  onClick={() => setShowConfirmPaid(true)}
                  className="w-full bg-green-600 hover:bg-green-500 text-white font-medium py-3 rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Mark Fine as Paid
                </button>
              ) : (
                <div className="bg-zinc-800/50 rounded-lg p-4 space-y-3">
                  <p className="text-white text-sm text-center">
                    Confirm mark fine <span className="text-amber-400 font-bold">#{localCharge.fine_id}</span> as paid?
                  </p>
                  <p className="text-zinc-400 text-xs text-center">
                    Amount: <span className="text-amber-400 font-bold">${localCharge.fine}</span>
                  </p>
                  <div className="flex gap-2">
                    <button
                      onClick={() => setShowConfirmPaid(false)}
                      disabled={markingPaid}
                      className="flex-1 bg-zinc-700 hover:bg-zinc-600 disabled:bg-zinc-800 text-white py-2 rounded-lg transition-colors"
                    >
                      Cancel
                    </button>
                    <button
                      onClick={handleMarkPaid}
                      disabled={markingPaid}
                      className="flex-1 bg-green-600 hover:bg-green-500 disabled:bg-zinc-700 text-white py-2 rounded-lg transition-colors flex items-center justify-center gap-2"
                    >
                      {markingPaid ? (
                        <>
                          <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                          </svg>
                          Processing...
                        </>
                      ) : (
                        'Confirm Paid'
                      )}
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      <ReportSelector
        isOpen={showReportSelector}
        onClose={() => setShowReportSelector(false)}
        onConfirm={handleAttachReports}
      />

      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}
    </div>
  );
}
