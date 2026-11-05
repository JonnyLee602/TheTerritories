import { useState, useEffect } from 'react';
import { fetchNui } from '../hooks/useNui';
import type { Fine } from '../types';

interface FinesPanelProps {
  citizenid: string;
}

function formatTimeRemaining(dueDate: string | null | undefined | number): { text: string; isOverdue: boolean; seconds: number } {
  if (!dueDate) {
    return { text: 'No due date', isOverdue: false, seconds: 0 };
  }
  
  let due: number;
  
  if (typeof dueDate === 'number') {
    if (dueDate > 1e12) {
      due = dueDate;
    } else if (dueDate > 1e9) {
      due = dueDate * 1000;
    } else {
      return { text: 'No due date', isOverdue: false, seconds: 0 };
    }
  } else {
    const dateStr = String(dueDate).trim();
    if (!dateStr || dateStr === 'null' || dateStr === 'undefined') {
      return { text: 'No due date', isOverdue: false, seconds: 0 };
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
    return { text: 'No due date', isOverdue: false, seconds: 0 };
  }
  
  const now = Date.now();
  const remaining = due - now;
  
  if (remaining <= 0) {
    return { text: 'OVERDUE', isOverdue: true, seconds: 0 };
  }
  
  const MAX_DAYS = 365;
  const days = Math.floor(remaining / 86400000);
  
  if (days > MAX_DAYS) {
    return { text: 'No due date', isOverdue: false, seconds: 0 };
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

export function FinesPanel({ citizenid }: FinesPanelProps) {
  const [fines, setFines] = useState<Fine[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchFines = async () => {
    setLoading(true);
    const result = await fetchNui<Fine[]>('getCitizenFines', { citizenid }, []);
    setFines(result || []);
    setLoading(false);
  };

  useEffect(() => {
    fetchFines();
  }, [citizenid]);

  const unpaidFines = fines.filter(f => f.status === 'unpaid' || f.status === 'overdue');
  const totalAmount = unpaidFines.reduce((sum, f) => sum + f.total_amount, 0);

  if (loading) {
    return (
      <div className="bg-zinc-800/50 rounded-lg p-4">
        <div className="text-zinc-400 text-sm">Loading fines...</div>
      </div>
    );
  }

  if (unpaidFines.length === 0) {
    return (
      <div className="bg-zinc-800/50 rounded-lg p-4">
        <div className="flex items-center gap-2 text-green-400 text-sm">
          <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
          </svg>
          No unpaid fines
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h5 className="text-zinc-400 text-sm font-bold uppercase tracking-wider flex items-center gap-2">
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          Unpaid Fines
        </h5>
        <span className="text-amber-400 font-bold">${totalAmount}</span>
      </div>

      <div className="space-y-2">
        {unpaidFines.map((fine) => {
          const timeInfo = formatTimeRemaining(fine.due_date);
          return (
            <div
              key={fine.id}
              className={`p-3 rounded-lg border ${
                fine.status === 'overdue'
                  ? 'bg-red-950/30 border-red-800'
                  : 'bg-zinc-800/50 border-zinc-700'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-white font-medium">Fine #{fine.id}</span>
                <span className={`text-sm font-bold ${
                  fine.status === 'overdue' ? 'text-red-400' : 'text-amber-400'
                }`}>
                  ${fine.total_amount}
                </span>
              </div>
              
              <div className="flex items-center justify-between text-xs">
                <span className="text-zinc-500">
                  Issued: {new Date(fine.issued_at).toLocaleDateString()}
                </span>
                <span className={`font-medium ${
                  timeInfo.isOverdue ? 'text-red-400' : 'text-zinc-400'
                }`}>
                  {timeInfo.isOverdue ? (
                    <span className="flex items-center gap-1">
                      <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                      </svg>
                      {timeInfo.text}
                    </span>
                  ) : (
                    `Due in ${timeInfo.text}`
                  )}
                </span>
              </div>
              
              {fine.officer_name && (
                <div className="mt-2 text-xs text-zinc-500">
                  Officer: {fine.officer_name}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
