import { useState, useEffect } from 'react';
import { fetchNui } from '../hooks/useNui';
import type { JobGrade } from '../types';

interface GradeDropdownProps {
  jobName: string;
  value: number;
  onChange: (grade: number) => void;
  disabled?: boolean;
}

export function GradeDropdown({ jobName, value, onChange, disabled }: GradeDropdownProps) {
  const [grades, setGrades] = useState<JobGrade[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!jobName) {
      setGrades([]);
      return;
    }

    const fetchGrades = async () => {
      setLoading(true);
      const result = await fetchNui<JobGrade[]>('getJobGrades', { jobName }, [
        { level: 0, label: 'Recruit', isAdmin: false },
        { level: 1, label: 'Deputy', isAdmin: false },
        { level: 2, label: 'Sheriff', isAdmin: true },
      ]);
      setGrades(result);
      if (result.length > 0 && value === undefined) {
        onChange(result[0].level);
      }
      setLoading(false);
    };

    fetchGrades();
  }, [jobName]);

  if (!jobName) return null;

  return (
    <div className="relative">
      <select
        value={value}
        onChange={(e) => onChange(parseInt(e.target.value, 10))}
        disabled={disabled || loading}
        className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-amber-600 disabled:opacity-50 disabled:cursor-not-allowed appearance-none"
      >
        {loading ? (
          <option value="">Loading grades...</option>
        ) : (
          grades.map((grade) => (
            <option key={grade.level} value={grade.level}>
              {grade.label}
              {grade.isAdmin ? ' (Admin)' : ''}
            </option>
          ))
        )}
      </select>
      <div className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
        {loading ? (
          <div className="w-4 h-4 border-2 border-amber-500 border-t-transparent rounded-full animate-spin" />
        ) : (
          <svg className="w-5 h-5 text-zinc-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        )}
      </div>
    </div>
  );
}
