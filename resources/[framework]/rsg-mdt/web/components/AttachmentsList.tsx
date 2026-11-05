import { useState, useEffect } from 'react';
import { fetchNui } from '../hooks/useNui';
import type { ChargeAttachment } from '../types';

interface AttachmentsListProps {
  chargeId: number;
  onAttachmentChange?: () => void;
  editable?: boolean;
  onViewReport?: (reportId: number) => void;
}

export function AttachmentsList({ chargeId, onAttachmentChange, editable = true, onViewReport }: AttachmentsListProps) {
  const [attachments, setAttachments] = useState<ChargeAttachment[]>([]);
  const [loading, setLoading] = useState(true);
  const [removingId, setRemovingId] = useState<number | null>(null);

  useEffect(() => {
    loadAttachments();
  }, [chargeId]);

  const loadAttachments = async () => {
    setLoading(true);
    const result = await fetchNui<ChargeAttachment[]>('getChargeAttachments', { chargeId }, []);
    setAttachments(result);
    setLoading(false);
  };

  const handleRemove = async (reportId: number) => {
    setRemovingId(reportId);
    const result = await fetchNui<{ success: boolean; message: string }>(
      'removeAttachmentFromCharge',
      { chargeId, reportId },
      { success: true, message: 'Attachment removed' }
    );
    
    if (result.success) {
      setAttachments(prev => prev.filter(a => a.report_id !== reportId));
      onAttachmentChange?.();
    }
    
    setRemovingId(null);
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

  if (loading) {
    return (
      <div className="bg-zinc-800/30 border border-zinc-700/50 rounded-lg p-4">
        <div className="flex items-center gap-2 text-zinc-500">
          <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          <span className="text-sm">Loading attachments...</span>
        </div>
      </div>
    );
  }

  if (attachments.length === 0) {
    return (
      <div className="bg-zinc-800/30 border border-zinc-800 border-dashed rounded-lg p-4 text-center">
        <svg className="w-8 h-8 text-zinc-600 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
        <p className="text-zinc-500 text-sm">No reports attached</p>
        {editable && (
          <p className="text-zinc-600 text-xs mt-1">Click "Attach Report" to add supporting documentation</p>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {attachments.map(attachment => (
        <div
          key={attachment.attachment_id}
          className="bg-zinc-800/50 border border-zinc-700/50 rounded-lg p-3 group hover:border-zinc-600 transition-colors"
        >
          <div className="flex items-start justify-between gap-3">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <svg className="w-4 h-4 text-zinc-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <span className="text-white font-medium truncate">{attachment.report_title}</span>
                <span className={`text-xs px-2 py-0.5 rounded border ${getTypeColor(attachment.report_type)}`}>
                  {attachment.report_type}
                </span>
              </div>
              <div className="flex items-center gap-4 mt-2 text-xs text-zinc-500">
                <span className="flex items-center gap-1">
                  <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                  </svg>
                  {attachment.report_officer}
                </span>
                <span className="flex items-center gap-1">
                  <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  {formatDate(attachment.report_created_at)}
                </span>
                <span className="text-zinc-600">Report #{attachment.report_id}</span>
              </div>
              <div className="flex items-center gap-2 mt-2 text-xs text-zinc-600">
                <span>Attached by {attachment.attached_by_name}</span>
                <span>on {formatDate(attachment.attached_at)}</span>
              </div>
            </div>

            <div className="flex items-center gap-1">
              {onViewReport && (
                <button
                  onClick={() => onViewReport(attachment.report_id)}
                  className="flex-shrink-0 p-1.5 text-zinc-500 hover:text-amber-400 hover:bg-amber-950/50 rounded transition-colors opacity-0 group-hover:opacity-100"
                  title="View Report"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                </button>
              )}
              {editable && (
                <button
                  onClick={() => handleRemove(attachment.report_id)}
                  disabled={removingId === attachment.report_id}
                  className="flex-shrink-0 p-1.5 text-zinc-500 hover:text-red-400 hover:bg-red-950/50 rounded transition-colors opacity-0 group-hover:opacity-100 disabled:opacity-50"
                  title="Remove attachment"
                >
                  {removingId === attachment.report_id ? (
                    <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                    </svg>
                  ) : (
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  )}
                </button>
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
