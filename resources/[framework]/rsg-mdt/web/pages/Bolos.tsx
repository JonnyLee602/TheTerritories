import React, { useState, useEffect } from 'react';
import { fetchNui, useNuiEvent } from '../hooks/useNui';
import { useConfirmDialog } from '../components/ConfirmDialog';
import type { BOLO } from '../types';

interface BolosProps {
  onRefresh?: () => void;
}

export function Bolos({ onRefresh }: BolosProps) {
  const [bolos, setBolos] = useState<BOLO[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ title: '', description: '', lastSeen: '' });
  const { confirm, dialog } = useConfirmDialog();

  const loadBolos = async () => {
    setLoading(true);
    const data = await fetchNui<BOLO[]>('getBolos', {}, [
      { id: 1, title: 'Suspicious Wagon', description: 'Black covered wagon seen near Rhodes', lastSeen: 'Near Rhodes', officer: 'Deputy Miller', date: '1899-03-20' },
      { id: 2, title: 'Armed Gang', description: 'Group of 5 armed men on horseback', lastSeen: 'Heading towards Valentine', officer: 'Sheriff Johnson', date: '1899-04-05' },
    ]);
    setBolos(data);
    setLoading(false);
  };

  useEffect(() => { loadBolos(); }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const success = await fetchNui<{ success: boolean }>('addBolo', form, { success: true });
    if (success.success) {
      setShowForm(false);
      setForm({ title: '', description: '', lastSeen: '' });
      loadBolos();
      onRefresh?.();
    }
  };

  const handleDelete = async (id: number) => {
    const confirmed = await confirm('Delete BOLO', 'Are you sure you want to delete this BOLO?');
    if (!confirmed) return;
    fetchNui('deleteBolo', { id }, { success: true });
  };

  useNuiEvent<{ success: boolean; id: number }>('boloDeleted', (data) => {
    if (data.success) {
      loadBolos();
      onRefresh?.();
    }
  });

  return (
    <div className="space-y-6">
      {dialog}
      <div className="flex justify-between items-center">
        <h2 className="text-white text-2xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
          BOLOs (Be On Lookout)
        </h2>
        <button
          onClick={() => setShowForm(true)}
          className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded-lg text-white text-sm transition-colors"
        >
          + Add BOLO
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="bg-zinc-900 border border-zinc-800 rounded-lg p-6 space-y-4">
          <input
            placeholder="Title"
            value={form.title}
            onChange={(e) => setForm({ ...form, title: e.target.value })}
            className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
            required
          />
          <textarea
            placeholder="Description"
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
            className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-blue-600 h-24"
            required
          />
          <input
            placeholder="Last Seen Location"
            value={form.lastSeen}
            onChange={(e) => setForm({ ...form, lastSeen: e.target.value })}
            className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
          />
          <div className="flex gap-3">
            <button type="submit" className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded text-white text-sm">
              Create BOLO
            </button>
            <button type="button" onClick={() => setShowForm(false)} className="bg-zinc-800 hover:bg-zinc-700 px-4 py-2 rounded text-zinc-300 text-sm">
              Cancel
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <p className="text-zinc-500">Loading BOLOs...</p>
      ) : bolos.length === 0 ? (
        <p className="text-zinc-500">No active BOLOs.</p>
      ) : (
        <div className="grid gap-4">
          {bolos.map((bolo) => (
            <div key={bolo.id} className="bg-gradient-to-r from-orange-950/20 to-zinc-900/50 border border-orange-900/30 rounded-lg p-4">
              <div className="flex justify-between items-start">
                <div>
                  <h3 className="text-white font-bold text-lg">{bolo.title}</h3>
                  <p className="text-zinc-400 text-sm mt-1">{bolo.description}</p>
                  {bolo.lastSeen && (
                    <p className="text-orange-400 text-sm mt-2">
                      <span className="text-orange-600">Last Seen:</span> {bolo.lastSeen}
                    </p>
                  )}
                </div>
                <button onClick={() => handleDelete(bolo.id)} className="text-red-500 hover:text-red-400 text-sm">
                  Remove
                </button>
              </div>
              <div className="flex gap-4 mt-3 pt-3 border-t border-orange-900/20 text-xs">
                <span className="text-zinc-500">Posted by: <span className="text-zinc-300">{bolo.officer}</span></span>
                <span className="text-zinc-500">Date: <span className="text-zinc-300">{bolo.date}</span></span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
