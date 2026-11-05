import { useState, useEffect } from 'react';
import { fetchNui } from '../hooks/useNui';
import type { LawJob, JobGrade } from '../types';
import { GradeDropdown } from './GradeDropdown';

interface OfficerDetailModalProps {
  officer: {
    citizenid: string;
    name: string;
    role: string;
    role_label?: string;
    jobName?: string;
    jobLabel?: string;
    gradeLevel?: number;
    gradeLabel?: string;
    isLaw: boolean;
  };
  lawJobs: LawJob[];
  onClose: () => void;
  onUpdated: () => Promise<void>;
}

export function OfficerDetailModal({ officer, lawJobs, onClose, onUpdated }: OfficerDetailModalProps) {
  const [selectedJob, setSelectedJob] = useState(officer.jobName || '');
  const [selectedGrade, setSelectedGrade] = useState(officer.gradeLevel || 0);
  const [availableGrades, setAvailableGrades] = useState<JobGrade[]>([]);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<{ type: 'success' | 'error'; message: string } | null>(null);
  const [showConfirm, setShowConfirm] = useState(false);

  useEffect(() => {
    if (!selectedJob) {
      setAvailableGrades([]);
      return;
    }

    const fetchGrades = async () => {
      const grades = await fetchNui<JobGrade[]>('getJobGrades', { jobName: selectedJob }, []);
      setAvailableGrades(grades);
    };

    fetchGrades();
  }, [selectedJob]);

  const handleSave = async () => {
    if (!selectedJob) {
      setToast({ type: 'error', message: 'Please select a department' });
      return;
    }

    setSaving(true);
    setToast(null);

    const result = await fetchNui<{ success: boolean; message: string; replacedJob?: string }>(
      'updateOfficerDepartment',
      {
        citizenid: officer.citizenid,
        job: selectedJob,
        grade: selectedGrade,
      },
      { success: true, message: 'Department updated successfully' }
    );

    setSaving(false);

    if (result.success) {
      const msg = result.replacedJob 
        ? `Transferred from ${result.replacedJob} to ${result.message.split(' to ')[1] || 'new department'}`
        : result.message;
      setToast({ type: 'success', message: msg });
      setTimeout(async () => {
        await onUpdated();
        onClose();
      }, 1000);
    } else {
      setToast({ type: 'error', message: result.message });
    }
  };

  const handleConfirmTransfer = () => {
    setShowConfirm(false);
    handleSave();
  };

  const selectedJobLabel = lawJobs.find(j => j.name === selectedJob)?.label;
  const selectedGradeLabel = availableGrades.find(g => g.level === selectedGrade)?.label;
  const hasChanges = selectedJob !== officer.jobName || selectedGrade !== officer.gradeLevel;
  const isReplacing = officer.isLaw && officer.jobName && officer.jobName !== selectedJob;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="absolute inset-0 bg-black/70" onClick={onClose} />
      <div className="relative bg-zinc-900 border border-zinc-700 rounded-xl w-full max-w-lg p-6">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-white text-lg font-bold" style={{ fontFamily: 'var(--font-display)' }}>
            Officer Details
          </h3>
          <button onClick={onClose} className="text-zinc-400 hover:text-white">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="space-y-4">
          <div className="bg-zinc-800 rounded-lg p-4">
            <div className="text-white font-medium text-lg">{officer.name}</div>
            <div className="text-zinc-500 text-sm font-mono">{officer.citizenid}</div>
            <div className="mt-3 flex gap-2 flex-wrap">
              <span className="px-2 py-1 rounded bg-amber-900/30 text-amber-400 text-xs">
                {officer.role_label || officer.role}
              </span>
              {officer.isLaw ? (
                <span className="px-2 py-1 rounded bg-blue-900/30 text-blue-400 text-xs">
                  {officer.jobLabel}
                </span>
              ) : (
                <span className="px-2 py-1 rounded bg-zinc-700 text-zinc-400 text-xs">
                  Not in law enforcement
                </span>
              )}
            </div>
          </div>

          {officer.isLaw && officer.jobName && (
            <div className="bg-zinc-800/50 border border-zinc-700 rounded-lg p-3">
              <div className="text-zinc-400 text-xs mb-1">Current Position</div>
              <div className="flex items-center gap-2">
                <span className="text-white">{officer.jobLabel}</span>
                <span className="text-zinc-500">•</span>
                <span className="text-zinc-300">{officer.gradeLabel}</span>
              </div>
            </div>
          )}

          <div className="border-t border-zinc-800 pt-4">
            <h4 className="text-zinc-400 text-sm mb-3">Change Department</h4>

            <div className="space-y-3">
              <div>
                <label className="block text-zinc-500 text-xs mb-1">Department</label>
                <select
                  value={selectedJob}
                  onChange={(e) => setSelectedJob(e.target.value)}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-amber-600"
                >
                  <option value="">Select department...</option>
                  {lawJobs.map((job) => (
                    <option key={job.name} value={job.name} disabled={job.name === officer.jobName}>
                      {job.label} {job.name === officer.jobName ? '(Current)' : ''}
                    </option>
                  ))}
                </select>
              </div>

              {selectedJob && (
                <div>
                  <label className="block text-zinc-500 text-xs mb-1">Grade</label>
                  <GradeDropdown
                    jobName={selectedJob}
                    value={selectedGrade}
                    onChange={setSelectedGrade}
                    disabled={false}
                  />
                </div>
              )}

              {selectedJob && hasChanges && (
                <div className="bg-zinc-800/50 border border-zinc-700 rounded-lg p-3">
                  <div className="text-zinc-400 text-xs mb-1">Transfer Summary</div>
                  <div className="text-sm">
                    <span className="text-white">{officer.name}</span>
                    <span className="text-zinc-500 mx-2">→</span>
                    <span className="text-amber-400">{selectedJobLabel}</span>
                    {selectedGradeLabel && (
                      <>
                        <span className="text-zinc-500 mx-1">as</span>
                        <span className="text-amber-300">{selectedGradeLabel}</span>
                      </>
                    )}
                  </div>
                  {isReplacing && (
                    <div className="mt-2 flex items-center gap-2 text-red-400 text-xs">
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                      </svg>
                      <span>This will remove their position at <strong>{officer.jobLabel}</strong></span>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>

        {toast && (
          <div
            className={`mt-4 p-3 rounded-lg ${
              toast.type === 'success'
                ? 'bg-green-900/30 border border-green-800 text-green-400'
                : 'bg-red-900/30 border border-red-800 text-red-400'
            }`}
          >
            {toast.message}
          </div>
        )}

        <div className="flex gap-3 mt-6">
          <button
            onClick={onClose}
            disabled={saving}
            className="flex-1 bg-zinc-700 hover:bg-zinc-600 disabled:opacity-50 py-3 rounded-lg text-white font-medium transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={() => isReplacing ? setShowConfirm(true) : handleSave()}
            disabled={!selectedJob || saving || !hasChanges}
            className="flex-1 bg-amber-600 hover:bg-amber-500 disabled:bg-zinc-700 disabled:text-zinc-500 py-3 rounded-lg text-white font-medium transition-colors"
          >
            {saving ? 'Saving...' : isReplacing ? 'Transfer Officer' : 'Save Changes'}
          </button>
        </div>
      </div>

      {showConfirm && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center">
          <div className="absolute inset-0 bg-black/80" onClick={() => setShowConfirm(false)} />
          <div className="relative bg-zinc-900 border border-red-900/50 rounded-xl w-full max-w-md p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-full bg-red-900/30">
                <svg className="w-6 h-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <h3 className="text-white text-lg font-bold">Confirm Transfer</h3>
            </div>

            <p className="text-zinc-300 mb-4">
              Are you sure you want to transfer <strong className="text-white">{officer.name}</strong> from <strong className="text-red-400">{officer.jobLabel}</strong> to <strong className="text-green-400">{selectedJobLabel}</strong>?
            </p>

            <div className="bg-red-900/20 border border-red-900/50 rounded-lg p-3 mb-4">
              <div className="text-red-400 text-sm">
                This will remove their current law enforcement position and assign them to the new department.
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setShowConfirm(false)}
                className="flex-1 bg-zinc-700 hover:bg-zinc-600 py-3 rounded-lg text-white font-medium transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleConfirmTransfer}
                className="flex-1 bg-red-600 hover:bg-red-500 py-3 rounded-lg text-white font-medium transition-colors"
              >
                Confirm Transfer
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
