import React, { useState, useEffect } from 'react';
import { fetchNui } from '../hooks/useNui';
import { useConfirmDialog } from '../components/ConfirmDialog';
import type { CriminalRecord } from '../types';

interface RecordsProps {
  onRefresh?: () => void;
}

export function Records({ onRefresh }: RecordsProps) {
  const [records, setRecords] = useState<CriminalRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ citizenid: '', name: '', crime: '', description: '', fine: 0, jailtime: 0 });
  const { confirm, dialog } = useConfirmDialog();

  const loadRecords = async () => {
    setLoading(true);
    const data = await fetchNui<CriminalRecord[]>('getRecords', {}, [
      { id: 1, citizenid: 'CIT001', name: 'John Marston', crime: 'Horse Theft', description: 'Stole a gray Arabian horse', fine: 250, jailtime: 0, officer: 'Sheriff Johnson', date: '1899-03-15' },
      { id: 2, citizenid: 'CIT002', name: 'Arthur Morgan', crime: 'Bank Robbery', description: 'Armed robbery of Lemoyne Bank', fine: 0, jailtime: 60, officer: 'Marshal Davis', date: '1899-05-20' },
    ]);
    setRecords(data);
    setLoading(false);
  };

  useEffect(() => { loadRecords(); }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const success = await fetchNui<{ success: boolean }>('addRecord', form, { success: true });
    if (success.success) {
      setShowForm(false);
      setForm({ citizenid: '', name: '', crime: '', description: '', fine: 0, jailtime: 0 });
      loadRecords();
      onRefresh?.();
    }
  };

  const handleDelete = async (id: number) => {
    const confirmed = await confirm('Delete Record', 'Are you sure you want to delete this criminal record?');
    if (!confirmed) return;
    await fetchNui('deleteRecord', { id }, { success: true });
    loadRecords();
    onRefresh?.();
  };

  return (
    <div className="space-y-6">
      {dialog}
      <div className="flex justify-between items-center">
        <h2 className="text-white text-2xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
          Criminal Records
        </h2>
        <button
          onClick={() => setShowForm(true)}
          className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded-lg text-white text-sm transition-colors"
        >
          + Add Record
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="bg-zinc-900 border border-zinc-800 rounded-lg p-6 space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <input
              placeholder="Citizen ID"
              value={form.citizenid}
              onChange={(e) => setForm({ ...form, citizenid: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
              required
            />
            <input
              placeholder="Full Name"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
              required
            />
            <input
              placeholder="Crime"
              value={form.crime}
              onChange={(e) => setForm({ ...form, crime: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
              required
            />
            <input
              placeholder="Description"
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
            />
            <div>
              <label className="block text-zinc-400 text-xs mb-1">Fine Amount ($)</label>
              <input
                type="number"
                placeholder="0"
                value={form.fine}
                onChange={(e) => setForm({ ...form, fine: Number(e.target.value) })}
                className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
              />
            </div>
            <div>
              <label className="block text-zinc-400 text-xs mb-1">Jail Time (minutes)</label>
              <input
                type="number"
                placeholder="0"
                value={form.jailtime}
                onChange={(e) => setForm({ ...form, jailtime: Number(e.target.value) })}
                className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
              />
            </div>
          </div>
          <div className="flex gap-3">
            <button type="submit" className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded text-white text-sm">
              Save Record
            </button>
            <button type="button" onClick={() => setShowForm(false)} className="bg-zinc-800 hover:bg-zinc-700 px-4 py-2 rounded text-zinc-300 text-sm">
              Cancel
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <p className="text-zinc-500">Loading records...</p>
      ) : records.length === 0 ? (
        <p className="text-zinc-500">No criminal records found.</p>
      ) : (
        <div className="space-y-3">
          {records.map((record) => (
            <div key={record.id} className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-4">
              <div className="flex justify-between items-start">
                <div>
                  <h3 className="text-white font-bold">{record.crime}</h3>
                  <p className="text-zinc-400 text-sm">{record.name} • {record.citizenid}</p>
                  {record.description && <p className="text-zinc-500 text-sm mt-1">{record.description}</p>}
                </div>
                <button onClick={() => handleDelete(record.id)} className="text-red-500 hover:text-red-400 text-sm">
                  Delete
                </button>
              </div>
              <div className="flex gap-4 mt-3 pt-3 border-t border-zinc-800 text-xs">
                <span className="text-zinc-500">Fine: <span className="text-zinc-300">${record.fine}</span></span>
                <span className="text-zinc-500">Jail: <span className="text-zinc-300">{record.jailtime} min</span></span>
                <span className="text-zinc-500">Officer: <span className="text-zinc-300">{record.officer}</span></span>
                <span className="text-zinc-500">Date: <span className="text-zinc-300">{record.date}</span></span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
