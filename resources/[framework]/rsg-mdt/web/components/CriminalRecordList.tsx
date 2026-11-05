import { useState, useEffect } from 'react';
import type { IssuedCharge } from '../types';

interface CriminalRecordListProps {
  charges: IssuedCharge[];
  loading: boolean;
  onChargeClick: (charge: IssuedCharge) => void;
  onRefresh?: () => void;
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
  
  if (days > 0) {
    return { text: `${days}d ${hours}h`, isOverdue: false, seconds: Math.floor(remaining / 1000) };
  } else if (hours > 0) {
    return { text: `${hours}h ${minutes}m`, isOverdue: false, seconds: Math.floor(remaining / 1000) };
  } else {
    return { text: `${minutes}m`, isOverdue: false, seconds: Math.floor(remaining / 1000) };
  }
}

function ChargeTimer({ dueDate, fineStatus }: { dueDate: string | null | undefined; fineStatus: string | null | undefined }) {
  const [timeInfo, setTimeInfo] = useState<TimeRemaining>(() => formatTimeRemaining(dueDate));
  
  useEffect(() => {
    if (fineStatus === 'paid' || !dueDate) return;
    
    const updateTimer = () => {
      setTimeInfo(formatTimeRemaining(dueDate));
    };
    
    updateTimer();
    const interval = setInterval(updateTimer, 1000);
    return () => clearInterval(interval);
  }, [dueDate, fineStatus]);
  
  if (fineStatus === 'paid') {
    return (
      <span className="flex items-center gap-1 text-green-400 text-xs font-medium">
        <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
        </svg>
        PAID
      </span>
    );
  }
  
  if (fineStatus === 'overdue' || timeInfo.isOverdue) {
    return (
      <span className="flex items-center gap-1 text-red-400 text-xs font-medium animate-pulse">
        <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
        </svg>
        OVERDUE
      </span>
    );
  }
  
  if (fineStatus === 'unpaid' && timeInfo.text) {
    return (
      <span className="flex items-center gap-1 text-amber-400 text-xs font-medium">
        <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        {timeInfo.text}
      </span>
    );
  }
  
  return null;
}

export function CriminalRecordList({ charges, loading, onChargeClick, onRefresh }: CriminalRecordListProps) {
   const formatDate = (dateString: unknown) => {
     if (!dateString) return 'Unknown';
     let date: Date;
     if (typeof dateString === 'string') {
       date = new Date(dateString);
     } else if (typeof dateString === 'number') {
       date = new Date(dateString * (dateString < 10000000000 ? 1000 : 1));
     } else {
       return 'Unknown';
     }
     if (isNaN(date.getTime())) return 'Unknown';
     return date.toLocaleDateString('en-US', {
       year: 'numeric',
       month: 'short',
       day: 'numeric',
       hour: '2-digit',
       minute: '2-digit'
     });
   };

  const getCategoryColor = (category: string) => {
    switch (category?.toLowerCase()) {
      case 'felony': return 'text-red-400 bg-red-400/10 border-red-400/30';
      case 'misdemeanor': return 'text-amber-400 bg-amber-400/10 border-amber-400/30';
      case 'infraction': return 'text-zinc-400 bg-zinc-400/10 border-zinc-400/30';
      default: return 'text-zinc-400 bg-zinc-400/10 border-zinc-400/30';
    }
  };

  const getStatusBadge = (fineStatus: string | null | undefined, fine: number) => {
    if (fine <= 0) return null;
    
    switch (fineStatus) {
      case 'paid':
        return (
          <span className="text-xs px-2 py-0.5 rounded border bg-green-400/10 text-green-400 border-green-400/30">
            Paid
          </span>
        );
      case 'overdue':
        return (
          <span className="text-xs px-2 py-0.5 rounded border bg-red-400/10 text-red-400 border-red-400/30 animate-pulse">
            Overdue
          </span>
        );
      case 'unpaid':
        return (
          <span className="text-xs px-2 py-0.5 rounded border bg-amber-400/10 text-amber-400 border-amber-400/30">
            Unpaid
          </span>
        );
      default:
        return null;
    }
  };

  const getJailTimeDisplay = (charge: IssuedCharge) => {
    if (!charge.jailtime || charge.jailtime <= 0) return null;
    
    if (charge.is_served || (charge.time_served && charge.time_served >= charge.jailtime)) {
      return (
        <span className="flex items-center gap-1 text-green-400 text-xs font-medium">
          <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
          </svg>
          {charge.jailtime} mo (served)
        </span>
      );
    }
    
    const remaining = charge.jailtime - (charge.time_served || 0);
    if (charge.time_served && charge.time_served > 0) {
      return (
        <span className="text-orange-400 text-xs font-medium">
          {remaining} mo remaining ({charge.time_served} served)
        </span>
      );
    }
    
    return <span className="text-red-400 text-xs font-medium">{charge.jailtime} mo</span>;
  };

  if (loading) {
    return (
      <div className="bg-zinc-800/30 rounded-lg p-4">
        <div className="animate-pulse space-y-3">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-16 bg-zinc-700/50 rounded-lg" />
          ))}
        </div>
      </div>
    );
  }

  if (!charges || charges.length === 0) {
    return (
      <div className="bg-zinc-800/30 rounded-lg p-6 text-center">
        <svg className="w-12 h-12 mx-auto text-zinc-600 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
        <p className="text-zinc-500 text-sm">No criminal records found</p>
        <p className="text-zinc-600 text-xs mt-1">This citizen has a clean record</p>
      </div>
    );
  }

  const totalFines = charges.reduce((sum, c) => sum + (c.fine || 0), 0);
  const totalJailtime = charges.reduce((sum, c) => sum + (c.jailtime || 0), 0);
  const totalServed = charges.reduce((sum, c) => sum + (c.time_served || 0), 0);
  const outstandingJailtime = totalJailtime - totalServed;
  const unpaidFines = charges.filter(c => c.fine > 0 && c.fine_status !== 'paid');

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4 text-sm">
          <span className="text-zinc-400">{charges.length} charge(s)</span>
          {totalFines > 0 && (
            <span className="text-amber-400 font-medium">${totalFines.toLocaleString()} total fines</span>
          )}
          {unpaidFines.length > 0 && (
            <span className="text-red-400 font-medium">{unpaidFines.length} unpaid</span>
          )}
          {totalJailtime > 0 && (
            <div className="flex items-center gap-2">
              <span className="text-red-400 font-medium">{totalJailtime} mo total</span>
              {totalServed > 0 && (
                <span className="text-green-400 font-medium">({totalServed} served)</span>
              )}
              {outstandingJailtime > 0 && (
                <span className="text-orange-400 font-medium">{outstandingJailtime} mo outstanding</span>
              )}
            </div>
          )}
        </div>
        {onRefresh && (
          <button
            onClick={onRefresh}
            className="text-zinc-500 hover:text-zinc-300 transition-colors"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>
        )}
      </div>

      <div className="space-y-2 max-h-64 overflow-y-auto pr-1">
        {charges.map((charge) => (
          <button
            key={charge.id}
            onClick={() => onChargeClick(charge)}
            className="w-full bg-zinc-800/50 hover:bg-zinc-800 border border-zinc-700/50 hover:border-zinc-600 rounded-lg p-3 text-left transition-all group"
          >
            <div className="flex items-start justify-between gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1 flex-wrap">
                  <span className="text-white font-medium truncate">{charge.charge_name}</span>
                  <span className={`text-xs px-2 py-0.5 rounded border ${getCategoryColor(charge.category || 'misdemeanor')}`}>
                    {charge.category || 'Charge'}
                  </span>
                  {getStatusBadge(charge.fine_status, charge.fine)}
                  {charge.is_served && charge.jailtime > 0 && (
                    <span className="text-xs px-2 py-0.5 rounded border bg-green-400/10 text-green-400 border-green-400/30">
                      Served
                    </span>
                  )}
                </div>
                {charge.charge_description && (
                  <p className="text-zinc-500 text-sm truncate">{charge.charge_description}</p>
                )}
              </div>
              <div className="flex items-center gap-2 text-xs text-zinc-500">
                <span>{formatDate(charge.created_at)}</span>
                <svg className="w-4 h-4 text-zinc-600 group-hover:text-zinc-400 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              </div>
            </div>
            
            <div className="flex items-center gap-4 mt-2 pt-2 border-t border-zinc-700/50 flex-wrap">
              <div className="flex items-center gap-1 text-xs">
                <svg className="w-3.5 h-3.5 text-zinc-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span className="text-zinc-400">Officer:</span>
                <span className="text-zinc-300">{charge.officer}</span>
              </div>
              {charge.fine > 0 && (
                <div className="flex items-center gap-2">
                  <span className="text-amber-400 text-xs font-medium">${charge.fine} fine</span>
                  <ChargeTimer dueDate={charge.due_date} fineStatus={charge.fine_status} />
                </div>
              )}
              {getJailTimeDisplay(charge)}
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
