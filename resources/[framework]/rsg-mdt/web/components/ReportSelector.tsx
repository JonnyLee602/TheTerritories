import { useState, useEffect, useMemo } from 'react';
import { fetchNui } from '../hooks/useNui';
import type { ReportForAttachment } from '../types';

interface ReportSelectorProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (selectedIds: number[]) => void;
  alreadyAttachedIds?: number[];
}

export function ReportSelector({ isOpen, onClose, onConfirm, alreadyAttachedIds = [] }: ReportSelectorProps) {
  const [reports, setReports] = useState<ReportForAttachment[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());

  useEffect(() => {
    if (isOpen) {
      loadReports();
      setSelectedIds(new Set());
      setSearchQuery('');
    }
  }, [isOpen]);

  const loadReports = async () => {
    setLoading(true);
    const result = await fetchNui<ReportForAttachment[]>('getAvailableReportsForAttachment', {}, [
      { id: 1, title: 'Bank Robbery Incident', type: 'incident', officer: 'Marshal Davis', created_at: '1899-05-15 14:30:00' },
      { id: 2, title: 'Assault Report', type: 'arrest', officer: 'Sheriff Johnson', created_at: '1899-06-02 21:15:00' },
      { id: 3, title: 'Horse Theft Report', type: 'investigation', officer: 'Deputy Miller', created_at: '1899-06-10 09:00:00' },
    ]);
    setReports(result);
    setLoading(false);
  };

  const filteredReports = useMemo(() => {
    if (!searchQuery.trim()) return reports;
    const query = searchQuery.toLowerCase();
    return reports.filter(r =>
      r.title.toLowerCase().includes(query) ||
      r.type.toLowerCase().includes(query) ||
      r.officer.toLowerCase().includes(query)
    );
  }, [reports, searchQuery]);

  const toggleReport = (id: number) => {
    const newSet = new Set(selectedIds);
    if (newSet.has(id)) {
      newSet.delete(id);
    } else {
      newSet.add(id);
    }
    setSelectedIds(newSet);
  };

  const toggleAll = () => {
    const selectableReports = filteredReports.filter(r => !alreadyAttachedIds.includes(r.id));
    if (selectedIds.size === selectableReports.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(selectableReports.map(r => r.id)));
    }
  };

  const handleConfirm = () => {
    onConfirm(Array.from(selectedIds));
    onClose();
  };

  const formatDate = (dateStr: unknown) => {
    if (!dateStr) return 'Unknown';
    if (typeof dateStr === 'string') {
      return dateStr.replace('T', ' ').split('.')[0];
    }
    if (typeof dateStr === 'number') {
      const date = new Date(dateStr * (dateStr < 10000000000 ? 1000 : 1));
      return date.toISOString().replace('T', ' ').split('.')[0];
    }
    return 'Unknown';
  };

  const getTypeColor = (type: string): string => {
    const colors: Record<string, string> = {
      incident: 'bg-red-950/50 text-red-400 border-red-800',
      arrest: 'bg-orange-950/50 text-orange-400 border-orange-800',
      investigation: 'bg-blue-950/50 text-blue-400 border-blue-800',
      traffic: 'bg-green-950/50 text-green-400 border-green-800',
    };
    return colors[type] || 'bg-zinc-800 text-zinc-400 border-zinc-700';
  };

  if (!isOpen) return null;

  const selectableReports = filteredReports.filter(r => !alreadyAttachedIds.includes(r.id));

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center" onClick={onClose}>
      <div className="absolute inset-0 bg-black/70" />
      <div
        className="relative bg-zinc-900 border border-zinc-700 rounded-xl w-full max-w-2xl max-h-[80vh] overflow-hidden shadow-2xl"
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-zinc-800">
          <div>
            <h3 className="text-white text-lg font-bold" style={{ fontFamily: 'var(--font-display)' }}>
              Attach Reports
            </h3>
            <p className="text-zinc-400 text-sm mt-1">
              Select reports to attach ({selectedIds.size} selected)
            </p>
          </div>
          <button onClick={onClose} className="text-zinc-400 hover:text-white transition-colors">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="p-4 border-b border-zinc-800">
          <div className="flex gap-3">
            <input
              type="text"
              placeholder="Search reports..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className="flex-1 bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
            />
            <button
              onClick={toggleAll}
              disabled={selectableReports.length === 0}
              className="bg-zinc-800 hover:bg-zinc-700 disabled:opacity-50 border border-zinc-700 rounded-lg px-4 py-2 text-zinc-300 text-sm transition-colors"
            >
              {selectedIds.size === selectableReports.length ? 'Deselect All' : 'Select All'}
            </button>
          </div>
        </div>

        <div className="overflow-y-auto max-h-[50vh] p-4">
          {loading ? (
            <div className="flex items-center justify-center py-8">
              <svg className="w-6 h-6 text-zinc-500 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
            </div>
          ) : filteredReports.length === 0 ? (
            <p className="text-zinc-500 text-center py-8">No reports found</p>
          ) : (
            <div className="space-y-2">
              {filteredReports.map(report => {
                const isAlreadyAttached = alreadyAttachedIds.includes(report.id);
                const isSelected = selectedIds.has(report.id);

                return (
                  <button
                    key={report.id}
                    onClick={() => !isAlreadyAttached && toggleReport(report.id)}
                    disabled={isAlreadyAttached}
                    className={`w-full text-left p-3 rounded-lg border transition-all ${
                      isAlreadyAttached
                        ? 'bg-zinc-800/30 border-zinc-800 cursor-not-allowed opacity-50'
                        : isSelected
                        ? 'bg-amber-600/20 border-amber-600'
                        : 'bg-zinc-800/50 border-zinc-700 hover:border-zinc-600'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="text-white font-medium truncate">{report.title}</span>
                          {isAlreadyAttached && (
                            <span className="text-xs px-2 py-0.5 rounded bg-green-900/50 text-green-400 border border-green-800">
                              Attached
                            </span>
                          )}
                        </div>
                        <div className="flex items-center gap-3 mt-1">
                          <span className={`text-xs px-2 py-0.5 rounded border ${getTypeColor(report.type)}`}>
                            {report.type}
                          </span>
                          <span className="text-zinc-500 text-xs">{report.officer}</span>
                        </div>
                      </div>
                      <div className="flex-shrink-0 text-right">
                        <p className="text-zinc-500 text-xs">#{report.id}</p>
                        <p className="text-zinc-600 text-xs">{formatDate(report.created_at)}</p>
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        <div className="p-4 border-t border-zinc-800 bg-zinc-900/50 flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 bg-zinc-700 hover:bg-zinc-600 rounded-lg px-4 py-2.5 text-white font-medium transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleConfirm}
            disabled={selectedIds.size === 0}
            className="flex-1 bg-amber-600 hover:bg-amber-500 disabled:bg-zinc-700 disabled:text-zinc-400 rounded-lg px-4 py-2.5 text-white font-medium transition-colors"
          >
            Attach {selectedIds.size} Report{selectedIds.size !== 1 ? 's' : ''}
          </button>
        </div>
      </div>
    </div>
  );
}
