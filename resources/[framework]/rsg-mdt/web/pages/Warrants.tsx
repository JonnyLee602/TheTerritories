import React, { useState, useEffect } from 'react';
import { fetchNui, useNuiEvent } from '../hooks/useNui';
import { useConfirmDialog } from '../components/ConfirmDialog';
import type { Warrant } from '../types';

interface WarrantPrefill {
  citizenid: string;
  name: string;
}

interface WarrantsProps {
  onRefresh?: () => void;
  prefill?: WarrantPrefill | null;
  onClearPrefill?: () => void;
}

export function Warrants({ onRefresh, prefill, onClearPrefill }: WarrantsProps) {
  const [warrants, setWarrants] = useState<Warrant[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ citizenid: '', name: '', reason: '' });
  const { confirm, dialog } = useConfirmDialog();

  const loadWarrants = async () => {
    setLoading(true);
    const data = await fetchNui<Warrant[]>('getWarrants', {}, [
      { id: 1, citizenid: 'CIT003', name: 'Dutch van der Linde', reason: 'Wanted for multiple bank robberies', status: 'active', officer: 'Marshal Davis', created_at: '1899-04-10' },
      { id: 2, citizenid: 'CIT004', name: 'Micah Bell', reason: 'Murder, conspiracy', status: 'active', officer: 'Sheriff Johnson', created_at: '1899-06-01' },
    ]);
    setWarrants(data);
    setLoading(false);
  };

  useEffect(() => { loadWarrants(); }, []);

  // Handle prefill from Citizen Lookup
  useEffect(() => {
    if (prefill) {
      setForm({ citizenid: prefill.citizenid, name: prefill.name, reason: '' });
      setShowForm(true);
      onClearPrefill?.();
    }
  }, [prefill, onClearPrefill]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const success = await fetchNui<{ success: boolean }>('addWarrant', form, { success: true });
    if (success.success) {
      setShowForm(false);
      setForm({ citizenid: '', name: '', reason: '' });
      loadWarrants();
      onRefresh?.();
    }
  };

  const handleUpdate = async (id: number, status: string) => {
    await fetchNui('updateWarrant', { id, status }, { success: true });
    loadWarrants();
    onRefresh?.();
  };

  const handleDelete = async (id: number) => {
    const confirmed = await confirm('Delete Warrant', 'Are you sure you want to delete this warrant?');
    if (!confirmed) return;
    fetchNui('deleteWarrant', { id }, { success: true });
  };

  useNuiEvent<{ success: boolean; id: number }>('warrantDeleted', (data) => {
    if (data.success) {
      loadWarrants();
      onRefresh?.();
    }
  });

  const statusColors: Record<string, string> = {
    active: 'text-red-400 bg-red-950/50',
    served: 'text-green-400 bg-green-950/50',
    expired: 'text-zinc-400 bg-zinc-800/50',
  };

  return (
    <div className="space-y-6">
      {dialog}
      <div className="flex justify-between items-center">
        <h2 className="text-white text-2xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
          Warrants
        </h2>
        <button
          onClick={() => setShowForm(true)}
          className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded-lg text-white text-sm transition-colors"
        >
          + Issue Warrant
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="bg-zinc-900 border border-zinc-800 rounded-lg p-6 space-y-4">
          <div className="grid grid-cols-3 gap-4">
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
              placeholder="Reason"
              value={form.reason}
              onChange={(e) => setForm({ ...form, reason: e.target.value })}
              className="bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
              required
            />
          </div>
          <div className="flex gap-3">
            <button type="submit" className="bg-amber-600 hover:bg-amber-500 px-4 py-2 rounded text-white text-sm">
              Issue Warrant
            </button>
            <button type="button" onClick={() => setShowForm(false)} className="bg-zinc-800 hover:bg-zinc-700 px-4 py-2 rounded text-zinc-300 text-sm">
              Cancel
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <p className="text-zinc-500">Loading warrants...</p>
      ) : warrants.length === 0 ? (
        <p className="text-zinc-500">No active warrants.</p>
      ) : (
        <div className="space-y-3">
          {warrants.map((warrant) => (
            <div key={warrant.id} className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-4">
              <div className="flex justify-between items-start">
                <div>
                  <div className="flex items-center gap-3">
                    <h3 className="text-white font-bold">{warrant.name}</h3>
                    <span className={`px-2 py-0.5 rounded text-xs uppercase ${statusColors[warrant.status]}`}>
                      {warrant.status}
                    </span>
                  </div>
                  <p className="text-zinc-400 text-sm">{warrant.citizenid}</p>
                  <p className="text-zinc-500 text-sm mt-1">{warrant.reason}</p>
                </div>
                <div className="flex gap-2">
                  {warrant.status === 'active' && (
                    <button onClick={() => handleUpdate(warrant.id, 'served')} className="text-green-500 hover:text-green-400 text-sm">
                      Mark Served
                    </button>
                  )}
                  <button onClick={() => handleDelete(warrant.id)} className="text-red-500 hover:text-red-400 text-sm">
                    Delete
                  </button>
                </div>
              </div>
              <div className="flex gap-4 mt-3 pt-3 border-t border-zinc-800 text-xs">
                <span className="text-zinc-500">Issued by: <span className="text-zinc-300">{warrant.officer}</span></span>
                <span className="text-zinc-500">Date: <span className="text-zinc-300">{warrant.created_at}</span></span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
