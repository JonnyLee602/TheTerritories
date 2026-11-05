import { useState, useEffect } from 'react';
import { fetchNui, useNuiEvent } from '../hooks/useNui';
import type { LawJob, PlayerForJob, JobGrade } from '../types';
import { GradeDropdown } from './GradeDropdown';

interface JobAssignmentProps {
  lawJobs: LawJob[];
}

export function JobAssignment({ lawJobs }: JobAssignmentProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<PlayerForJob[]>([]);
  const [searching, setSearching] = useState(false);
  const [selectedPlayer, setSelectedPlayer] = useState<PlayerForJob | null>(null);
  const [selectedJob, setSelectedJob] = useState('');
  const [selectedGrade, setSelectedGrade] = useState<number>(0);
  const [availableGrades, setAvailableGrades] = useState<JobGrade[]>([]);
  const [assigning, setAssigning] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  useNuiEvent('jobAssigned', (data: { name: string; jobLabel: string; replacedJob?: string }) => {
    if (data.replacedJob) {
      setMessage({ 
        type: 'success', 
        text: `${data.name} was transferred from ${data.replacedJob} to ${data.jobLabel}` 
      });
    } else {
      setMessage({ 
        type: 'success', 
        text: `${data.name} was assigned to ${data.jobLabel}` 
      });
    }
  });

  useEffect(() => {
    if (!selectedJob) {
      setAvailableGrades([]);
      setSelectedGrade(0);
      return;
    }

    const fetchGrades = async () => {
      const grades = await fetchNui<JobGrade[]>('getJobGrades', { jobName: selectedJob }, [
        { level: 0, label: 'Recruit', isAdmin: false },
        { level: 1, label: 'Deputy', isAdmin: false },
        { level: 2, label: 'Sheriff', isAdmin: true },
      ]);
      setAvailableGrades(grades);
      if (grades.length > 0) {
        setSelectedGrade(grades[0].level);
      }
    };

    fetchGrades();
  }, [selectedJob]);

  const handleSearch = async (query: string) => {
    setSearchQuery(query);
    if (query.length < 2) {
      setSearchResults([]);
      return;
    }
    setSearching(true);
    const results = await fetchNui<PlayerForJob[]>('searchPlayersForJob', { query }, []);
    setSearchResults(results);
    setSearching(false);
  };

  const handleSelectPlayer = (player: PlayerForJob) => {
    setSelectedPlayer(player);
    setSearchQuery(`${player.charinfo?.firstname} ${player.charinfo?.lastname}`);
    setSearchResults([]);
    setMessage(null);
  };

  const handleCancel = () => {
    setSelectedPlayer(null);
    setSelectedJob('');
    setSelectedGrade(0);
    setSearchQuery('');
    setMessage(null);
  };

  const handleAssignJob = async () => {
    if (!selectedPlayer || !selectedJob) return;

    setAssigning(true);
    const result = await fetchNui<{ success: boolean; message: string; playerName?: string; jobLabel?: string; gradeLabel?: string; replacedJob?: string }>(
      'assignLawJob',
      { citizenid: selectedPlayer.citizenid, job: selectedJob, grade: selectedGrade },
      { success: true, message: 'Job assigned successfully' }
    );
    setAssigning(false);
    setShowConfirm(false);

    if (result.success) {
      const msg = result.replacedJob
        ? `${result.playerName} transferred from ${result.replacedJob} to ${result.jobLabel} as ${result.gradeLabel}`
        : result.message;
      setMessage({ type: 'success', text: msg });
      setSelectedPlayer(null);
      setSelectedJob('');
      setSelectedGrade(0);
      setSearchQuery('');
    } else {
      setMessage({ type: 'error', text: result.message });
    }
  };

  const selectedJobLabel = lawJobs.find(j => j.name === selectedJob)?.label;
  const selectedGradeLabel = availableGrades.find(g => g.level === selectedGrade)?.label;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white" style={{ fontFamily: 'var(--font-display)' }}>
          Job Assignment
        </h2>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-lg p-6">
        <p className="text-zinc-400 text-sm mb-6">
          Assign a law enforcement job and grade to a player. Players must be online to receive a job assignment.
        </p>

        {message && (
          <div
            className={`mb-4 p-3 rounded-lg ${
              message.type === 'success'
                ? 'bg-green-900/30 border border-green-800 text-green-400'
                : 'bg-red-900/30 border border-red-800 text-red-400'
            }`}
          >
            {message.text}
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div>
            <label className="block text-zinc-400 text-sm mb-2">Search Player</label>
            <div className="relative">
              <input
                type="text"
                placeholder="Search by name or citizen ID..."
                value={searchQuery}
                onChange={(e) => handleSearch(e.target.value)}
                className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
              />
              {searching && (
                <div className="absolute right-3 top-1/2 -translate-y-1/2">
                  <div className="w-4 h-4 border-2 border-amber-500 border-t-transparent rounded-full animate-spin" />
                </div>
              )}
            </div>

            {searchResults.length > 0 && (
              <div className="mt-2 bg-zinc-800 border border-zinc-700 rounded-lg max-h-48 overflow-y-auto">
                {searchResults.map((player) => (
                  <button
                    key={player.citizenid}
                    onClick={() => handleSelectPlayer(player)}
                    className="w-full px-4 py-3 text-left hover:bg-zinc-700 flex items-center justify-between border-b border-zinc-700 last:border-b-0"
                  >
                    <div>
                      <div className="text-white">
                        {player.charinfo?.firstname} {player.charinfo?.lastname}
                      </div>
                      <div className="text-zinc-500 text-sm font-mono">{player.citizenid}</div>
                    </div>
                    <div className="text-right">
                      {player.hasLawJob ? (
                        <span className="text-amber-400 text-sm">{player.lawJobName}</span>
                      ) : (
                        <span className="text-zinc-500 text-sm">{player.job?.label || 'Unemployed'}</span>
                      )}
                    </div>
                  </button>
                ))}
              </div>
            )}

            {selectedPlayer && (
              <div className="mt-4 p-4 bg-zinc-800 border border-zinc-700 rounded-lg">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-white font-medium">
                      {selectedPlayer.charinfo?.firstname} {selectedPlayer.charinfo?.lastname}
                    </div>
                    <div className="text-zinc-500 text-sm font-mono">{selectedPlayer.citizenid}</div>
                  </div>
                  <button
                    onClick={handleCancel}
                    className="text-zinc-400 hover:text-white text-sm"
                  >
                    Clear
                  </button>
                </div>
                <div className="mt-2">
                  {selectedPlayer.hasLawJob ? (
                    <span className="inline-flex items-center px-2 py-1 rounded bg-amber-900/30 text-amber-400 text-sm">
                      Current: {selectedPlayer.lawJobName}
                    </span>
                  ) : (
                    <span className="inline-flex items-center px-2 py-1 rounded bg-zinc-700 text-zinc-300 text-sm">
                      Current: {selectedPlayer.job?.label || 'No Job'}
                    </span>
                  )}
                </div>
              </div>
            )}
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-zinc-400 text-sm mb-2">Select Department</label>
              <select
                value={selectedJob}
                onChange={(e) => {
                  setSelectedJob(e.target.value);
                  setMessage(null);
                }}
                disabled={!selectedPlayer}
                className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-amber-600 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <option value="">Choose a department...</option>
                {lawJobs.map((job) => (
                  <option key={job.name} value={job.name}>
                    {job.label}
                  </option>
                ))}
              </select>
            </div>

            {selectedJob && (
              <div>
                <label className="block text-zinc-400 text-sm mb-2">Select Grade</label>
                <GradeDropdown
                  jobName={selectedJob}
                  value={selectedGrade}
                  onChange={setSelectedGrade}
                  disabled={!selectedPlayer}
                />
              </div>
            )}

            {selectedJob && selectedGradeLabel && (
              <div className="p-4 bg-zinc-800 border border-zinc-700 rounded-lg">
                <div className="text-zinc-400 text-sm mb-2">Assignment Summary</div>
                <div className="text-white">
                  <span className="font-medium">
                    {selectedPlayer?.charinfo?.firstname} {selectedPlayer?.charinfo?.lastname}
                  </span>
                  <span className="text-zinc-500 mx-2">→</span>
                  <span className="text-amber-400">{selectedJobLabel}</span>
                  <span className="text-zinc-500 mx-1">as</span>
                  <span className="text-amber-300">{selectedGradeLabel}</span>
                </div>
                {selectedPlayer?.hasLawJob && (
                  <div className="mt-2 text-amber-400 text-sm">
                    Warning: This will replace their current law job ({selectedPlayer.lawJobName})
                  </div>
                )}
              </div>
            )}

            <div className="flex gap-3">
              <button
                onClick={handleCancel}
                disabled={!selectedPlayer && !selectedJob}
                className="flex-1 bg-zinc-700 hover:bg-zinc-600 disabled:bg-zinc-800 disabled:text-zinc-600 py-3 rounded-lg text-white font-medium transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => setShowConfirm(true)}
                disabled={!selectedPlayer || !selectedJob || assigning}
                className="flex-1 bg-amber-600 hover:bg-amber-500 disabled:bg-zinc-700 disabled:text-zinc-500 py-3 rounded-lg text-white font-medium transition-colors"
              >
                {assigning ? 'Assigning...' : 'Save Assignment'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {showConfirm && selectedPlayer && selectedJob && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div className="absolute inset-0 bg-black/70" onClick={() => setShowConfirm(false)} />
          <div className="relative bg-zinc-900 border border-zinc-700 rounded-xl w-full max-w-md p-6">
            <h3 className="text-white text-lg font-bold mb-4">
              {selectedPlayer.hasLawJob ? 'Confirm Job Transfer' : 'Confirm Job Assignment'}
            </h3>
            
            {selectedPlayer.hasLawJob ? (
              <div className="space-y-4">
                <p className="text-zinc-300">
                  Transfer <strong className="text-white">{selectedPlayer.charinfo?.firstname} {selectedPlayer.charinfo?.lastname}</strong> from <strong className="text-red-400">{selectedPlayer.lawJobName}</strong> to <strong className="text-green-400">{selectedJobLabel}</strong> as <strong className="text-amber-400">{selectedGradeLabel}</strong>?
                </p>
                <div className="bg-red-900/20 border border-red-900/50 rounded-lg p-3">
                  <div className="text-red-400 text-sm">
                    This will remove their current law enforcement position before assigning the new role.
                  </div>
                </div>
              </div>
            ) : (
              <p className="text-zinc-300">
                Assign <strong className="text-white">{selectedPlayer.charinfo?.firstname} {selectedPlayer.charinfo?.lastname}</strong> to <strong className="text-amber-400">{selectedJobLabel}</strong> as <strong className="text-amber-300">{selectedGradeLabel}</strong>?
              </p>
            )}

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setShowConfirm(false)}
                className="flex-1 bg-zinc-700 hover:bg-zinc-600 py-3 rounded-lg text-white font-medium transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleAssignJob}
                disabled={assigning}
                className={`flex-1 py-3 rounded-lg text-white font-medium transition-colors ${
                  selectedPlayer.hasLawJob
                    ? 'bg-red-600 hover:bg-red-500'
                    : 'bg-amber-600 hover:bg-amber-500'
                } disabled:opacity-50`}
              >
                {assigning ? 'Processing...' : selectedPlayer.hasLawJob ? 'Confirm Transfer' : 'Assign'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
