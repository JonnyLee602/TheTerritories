import React, { useState, useEffect, useCallback } from 'react';
import { fetchNui } from '../hooks/useNui';
import { useNuiEvent } from '../hooks/useNui';
import { useConfirmDialog } from '../components/ConfirmDialog';
import type { ChargeTemplate, ChargeFormData } from '../types';

const categories = [
  { value: 'felony', label: 'Felony', color: 'bg-red-950/50 text-red-400 border-red-800' },
  { value: 'misdemeanor', label: 'Misdemeanor', color: 'bg-amber-950/50 text-amber-400 border-amber-800' },
  { value: 'infraction', label: 'Infraction', color: 'bg-blue-950/50 text-blue-400 border-blue-800' },
];

export function AdminChargesManager() {
  const [templates, setTemplates] = useState<ChargeTemplate[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [editing, setEditing] = useState<ChargeTemplate | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState<ChargeFormData>({
    name: '',
    description: '',
    fine: 0,
    jailtime: 0,
    category: 'misdemeanor',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const { confirm, dialog } = useConfirmDialog();

  const fetchTemplates = useCallback(async () => {
    const result = await fetchNui<ChargeTemplate[]>('getChargeTemplates', {}, []);
    setTemplates(result);
  }, []);

  useEffect(() => {
    fetchTemplates();
  }, [fetchTemplates]);

  useNuiEvent('chargesUpdated', () => {
    fetchTemplates();
  });

  const filteredTemplates = searchQuery.trim()
    ? templates.filter(t =>
        t.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (t.description && t.description.toLowerCase().includes(searchQuery.toLowerCase()))
      )
    : templates;

  const groupedTemplates = categories.reduce((acc, cat) => {
    acc[cat.value] = filteredTemplates.filter(t => t.category === cat.value);
    return acc;
  }, {} as Record<string, ChargeTemplate[]>);

  const resetForm = () => {
    setFormData({
      name: '',
      description: '',
      fine: 0,
      jailtime: 0,
      category: 'misdemeanor',
    });
    setEditing(null);
    setShowForm(false);
    setError(null);
  };

  const handleEdit = (template: ChargeTemplate) => {
    setFormData({
      name: template.name,
      description: template.description || '',
      fine: template.fine,
      jailtime: template.jailtime,
      category: template.category,
    });
    setEditing(template);
    setShowForm(true);
    setError(null);
  };

  const handleDelete = async (id: number, name: string) => {
    const confirmed = await confirm('Delete Charge', `Are you sure you want to delete "${name}"? This cannot be undone.`);
    if (!confirmed) return;
    fetchNui('deleteChargeTemplate', { id }, { success: true, message: 'Deleted' });
  };

  useNuiEvent<{ success: boolean; message: string; id: number }>('chargeTemplateDeleted', (data) => {
    if (data.success) {
      setTemplates(prev => prev.filter(t => t.id !== data.id));
      setSuccess('Charge template deleted');
      setTimeout(() => setSuccess(null), 3000);
    } else {
      setError(data.message || 'Failed to delete');
    }
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      setError('Charge name is required');
      return;
    }

    setSaving(true);
    setError(null);

    const payload = editing
      ? { id: editing.id, ...formData }
      : formData;

    const callback = editing ? 'updateChargeTemplate' : 'addChargeTemplate';
    const result = await fetchNui<{ success: boolean; message: string; id?: number }>(
      callback,
      payload,
      { success: true, message: 'Saved' }
    );

    setSaving(false);

    if (result.success) {
      await fetchTemplates();
      resetForm();
      setSuccess(editing ? 'Charge template updated' : 'Charge template created');
      setTimeout(() => setSuccess(null), 3000);
    } else {
      setError(result.message || 'Failed to save');
    }
  };

  return (
    <div className="h-full flex flex-col">
      {dialog}
      <div className="flex items-center justify-between mb-4">
        <div className="flex-1 max-w-md">
          <input
            type="text"
            placeholder="Search charge templates..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600"
          />
        </div>
        <button
          onClick={() => {
            resetForm();
            setShowForm(true);
          }}
          className="ml-4 bg-amber-600 hover:bg-amber-500 rounded-lg px-4 py-2 text-white font-medium transition-colors"
        >
          + Add Charge
        </button>
      </div>

      {success && (
        <div className="mb-4 bg-green-950/50 border border-green-800 text-green-400 px-4 py-2 rounded-lg">
          {success}
        </div>
      )}

      {showForm && (
        <div className="mb-4 bg-zinc-800/50 border border-zinc-700 rounded-xl p-4">
          <h4 className="text-white font-bold mb-4">
            {editing ? 'Edit Charge Template' : 'New Charge Template'}
          </h4>

          {error && (
            <p className="text-red-400 text-sm mb-3">{error}</p>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-zinc-400 text-sm mb-1">Name *</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={e => setFormData(prev => ({ ...prev, name: e.target.value }))}
                  className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-amber-600"
                  placeholder="e.g., Assault"
                />
              </div>
              <div>
                <label className="block text-zinc-400 text-sm mb-1">Category</label>
                <select
                  value={formData.category}
                  onChange={e => setFormData(prev => ({ ...prev, category: e.target.value }))}
                  className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-amber-600"
                >
                  {categories.map(cat => (
                    <option key={cat.value} value={cat.value}>{cat.label}</option>
                  ))}
                </select>
              </div>
            </div>

            <div>
              <label className="block text-zinc-400 text-sm mb-1">Description</label>
              <textarea
                value={formData.description}
                onChange={e => setFormData(prev => ({ ...prev, description: e.target.value }))}
                className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-amber-600 resize-none"
                rows={2}
                placeholder="Brief description of the charge..."
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-zinc-400 text-sm mb-1">Fine Amount ($)</label>
                <input
                  type="number"
                  min="0"
                  value={formData.fine}
                  onChange={e => setFormData(prev => ({ ...prev, fine: parseInt(e.target.value) || 0 }))}
                  className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-amber-600"
                />
              </div>
              <div>
                <label className="block text-zinc-400 text-sm mb-1">Jail Time (months)</label>
                <input
                  type="number"
                  min="0"
                  value={formData.jailtime}
                  onChange={e => setFormData(prev => ({ ...prev, jailtime: parseInt(e.target.value) || 0 }))}
                  className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-amber-600"
                />
              </div>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="button"
                onClick={resetForm}
                className="flex-1 bg-zinc-700 hover:bg-zinc-600 rounded-lg px-4 py-2 text-white font-medium transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={saving}
                className="flex-1 bg-amber-600 hover:bg-amber-500 disabled:bg-zinc-700 rounded-lg px-4 py-2 text-white font-medium transition-colors"
              >
                {saving ? 'Saving...' : (editing ? 'Update' : 'Create')}
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="flex-1 overflow-y-auto space-y-6">
        {categories.map(cat => {
          const charges = groupedTemplates[cat.value] || [];
          if (charges.length === 0 && searchQuery) return null;

          return (
            <div key={cat.value}>
              <div className="flex items-center gap-2 mb-3">
                <span className={`text-sm px-2 py-1 rounded border ${cat.color}`}>
                  {cat.label}
                </span>
                <span className="text-zinc-500 text-sm">({charges.length})</span>
              </div>

              {charges.length === 0 ? (
                <p className="text-zinc-600 text-sm pl-4">No charges in this category</p>
              ) : (
                <div className="grid gap-2">
                  {charges.map(charge => (
                    <div
                      key={charge.id}
                      className="bg-zinc-800/30 border border-zinc-700/50 rounded-lg p-3 flex items-center justify-between"
                    >
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <span className="text-white font-medium">{charge.name}</span>
                        </div>
                        {charge.description && (
                          <p className="text-zinc-400 text-sm mt-1">{charge.description}</p>
                        )}
                        <div className="flex gap-4 mt-1 text-xs">
                          {charge.fine > 0 && <span className="text-amber-400">Fine: ${charge.fine}</span>}
                          {charge.jailtime > 0 && <span className="text-red-400">Jail: {charge.jailtime}mo</span>}
                          {!charge.fine && !charge.jailtime && (
                            <span className="text-zinc-500">No penalties set</span>
                          )}
                        </div>
                      </div>
                      <div className="flex gap-2">
                        <button
                          onClick={() => handleEdit(charge)}
                          className="text-zinc-400 hover:text-amber-400 transition-colors"
                        >
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                          </svg>
                        </button>
                        <button
                          onClick={() => handleDelete(charge.id, charge.name)}
                          className="text-zinc-400 hover:text-red-400 transition-colors"
                        >
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                          </svg>
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
